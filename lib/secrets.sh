#!/bin/bash
# Secret key management using age encryption.
# shellcheck shell=bash

[[ -v SECRETS_DIR ]] || readonly SECRETS_DIR="${SCRIPT_DIR}/secrets"

readonly SECRETS_BUNDLE="${SECRETS_DIR}/secrets.tar.gz.age"

#######################################
# secrets::install_age
# Install age encryption tool via package manager or binary download.
# Globals:
#   OS_TYPE
# Outputs:
#   Step/success/warn messages
#######################################
secrets::install_age() {
  if core::have age; then
    note "age already installed"
    return 0
  fi

  step "Installing age"
  case "${OS_TYPE}" in
    debian | arch | macos | redhat)
      if pkg::install age; then
        success "age installed"
        return 0
      fi
      ;;
  esac

  # Fallback: download binary from GitHub releases
  secrets::install_age_fallback
}

# core::get_arch — REMOVED, use core::get_arch

#######################################
# secrets::install_age_fallback
# Download age binary directly from GitHub releases.
# Outputs:
#   Step/success/warn messages
# Returns:
#   0 on success, 1 on failure
#######################################
secrets::install_age_fallback() {
  local age_version="1.2.0" age_arch tmpd tar_gz url os_name

  if ! age_arch="$(core::get_arch)"; then
    warn "Unsupported arch for age fallback ($(uname -m))"
    return 1
  fi

  case "${OSTYPE}" in
    linux*) os_name="linux" ;;
    darwin*) os_name="darwin" ;;
    *)
      warn "Unsupported OS for age fallback"
      return 1
      ;;
  esac

  tmpd="$(mktemp -d)" || {
    warn "Failed to create temp dir for age"
    return 1
  }

  tar_gz="age-v${age_version}-${os_name}-${age_arch}.tar.gz"
  url="https://github.com/FiloSottile/age/releases/download"
  url="${url}/v${age_version}/${tar_gz}"
  step "Downloading age ${age_version} (fallback)"

  if ! core::run curl -fsSL "${url}" -o "${tmpd}/${tar_gz}"; then
    warn "age download failed"
    rm -rf "${tmpd}"
    return 1
  fi

  if ! core::run tar -xzf "${tmpd}/${tar_gz}" -C "${tmpd}"; then
    warn "age extraction failed"
    rm -rf "${tmpd}"
    return 1
  fi

  dev_tools::install_binary "${tmpd}/age/age" age
  dev_tools::install_binary "${tmpd}/age/age-keygen" age-keygen
  rm -rf "${tmpd}"

  if core::have age; then
    success "age (fallback)"
    return 0
  fi

  warn "age installed but not in PATH"
  return 1
}

#######################################
# secrets::has_bundle
# Check if the encrypted secrets bundle exists.
# Returns:
#   0 if bundle exists, 1 otherwise
#######################################
secrets::has_bundle() {
  [[ -f "${SECRETS_BUNDLE}" ]]
}

#######################################
# secrets::prompt_passphrase
# Prompt user for the secrets passphrase.
# Outputs:
#   Passphrase on stdout
# Returns:
#   0 on success, 1 if no TTY
#######################################
secrets::prompt_passphrase() {
  if [[ ! -e /dev/tty ]]; then
    warn "No TTY available for passphrase prompt"
    return 1
  fi

  if core::have gum; then
    gum input --password \
      --placeholder "Enter secrets passphrase" \
      --prompt "🔑 " --prompt.foreground 212 < /dev/tty
    return $?
  fi

  local passphrase
  printf "%b?%b Enter secrets passphrase: " \
    "${C_CYAN}" "${C_RESET}" >&2
  read -rs passphrase < /dev/tty
  printf "\n" >&2
  echo "${passphrase}"
}

#######################################
# secrets::apply_permissions
# Set file permissions from the manifest after extraction.
# Globals:
#   SECRETS_DIR
#   HOME
#######################################
secrets::apply_permissions() {
  local manifest="${SECRETS_DIR}/manifest.txt"
  [[ -f "${manifest}" ]] || return 0

  local encrypted dest perms
  while IFS=: read -r encrypted dest perms; do
    [[ -z "${encrypted}" || "${encrypted}" == \#* ]] && continue
    dest="${dest/#\~/${HOME}}"
    if [[ -f "${dest}" && -n "${perms}" ]]; then
      chmod "${perms}" "${dest}"
    fi
  done < "${manifest}"
}

#######################################
# secrets::decrypt_bundle
# Decrypt and extract the secrets archive.
# Globals:
#   SECRETS_BUNDLE
#   HOME
# Returns:
#   0 on success, 1 on failure
#######################################
secrets::decrypt_bundle() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) decrypt ${SECRETS_BUNDLE} → \$HOME"
    return 0
  fi

  local passphrase
  passphrase="$(secrets::prompt_passphrase)" || return 1

  local tmptar
  tmptar="$(mktemp)"

  if ! printf '%s' "${passphrase}" |
    age -d -o "${tmptar}" "${SECRETS_BUNDLE}" 2> /dev/null; then
    rm -f "${tmptar}"
    error "Decryption failed (wrong passphrase?)"
    return 1
  fi

  if ! tar -xzf "${tmptar}" -C "${HOME}"; then
    rm -f "${tmptar}"
    error "Archive extraction failed"
    return 1
  fi

  rm -f "${tmptar}"
  secrets::apply_permissions
  return 0
}

#######################################
# secrets::setup
# Main orchestrator for secrets decryption during install.
# Outputs:
#   Headline and delegated messages
#######################################
secrets::setup() {
  headline "Secrets"

  if [[ "${SKIP_SECRETS:-0}" == "1" ]]; then
    note "Skipping secrets (--skip-secrets)"
    return 0
  fi

  secrets::install_age

  if ! secrets::has_bundle; then
    note "No secrets bundle found — skipping"
    return 0
  fi

  info "Encrypted secrets bundle detected"

  if [[ ! -e /dev/tty ]]; then
    note "No TTY — skipping secrets (re-run interactively)"
    return 0
  fi

  if core::have gum; then
    if ! gum confirm "Decrypt secrets now?" < /dev/tty; then
      note "Skipped — re-run the installer later to decrypt"
      return 0
    fi
  fi

  step "Decrypting secrets"
  if secrets::decrypt_bundle; then
    success "Secrets decrypted and installed"
  else
    warn "Decrypt failed — re-run the installer later"
  fi
}
