#!/bin/bash
# Secret key management using age encryption.
# shellcheck shell=bash

[[ -v SECRETS_DIR ]] || readonly SECRETS_DIR="${SCRIPT_DIR}/secrets"

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
    debian)
      if pkg::install age; then
        success "age installed"
        return 0
      fi
      ;;
    arch)
      if pkg::install age; then
        success "age installed"
        return 0
      fi
      ;;
    macos)
      if pkg::install age; then
        success "age installed"
        return 0
      fi
      ;;
    redhat)
      if pkg::install age; then
        success "age installed"
        return 0
      fi
      ;;
  esac

  # Fallback: download binary from GitHub releases
  secrets::install_age_fallback
}

#######################################
# secrets::get_age_arch
# Detect architecture name for age binary download.
# Outputs:
#   arch string (amd64/arm64) or returns 1
#######################################
secrets::get_age_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *) return 1 ;;
  esac
}

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

  if ! age_arch="$(secrets::get_age_arch)"; then
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
  url="https://github.com/FiloSottile/age/releases/download/v${age_version}/${tar_gz}"
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
# secrets::has_encrypted_files
# Check if there are any encrypted secret files to process.
# Returns:
#   0 if encrypted files exist, 1 otherwise
#######################################
secrets::has_encrypted_files() {
  compgen -G "${SECRETS_DIR}/*.age" > /dev/null 2>&1
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
    gum input --password --placeholder "Enter secrets passphrase" \
      --prompt "🔑 " --prompt.foreground 212 < /dev/tty
    return $?
  fi

  local passphrase
  printf "%b?%b Enter secrets passphrase: " "${C_CYAN}" "${C_RESET}" >&2
  read -rs passphrase < /dev/tty
  printf "\n" >&2
  echo "${passphrase}"
}

#######################################
# secrets::decrypt_file
# Decrypt a single .age file to its target location.
# Arguments:
#   1 - encrypted file path (e.g., secrets/ssh_id_ed25519.age)
#   2 - destination path (e.g., ~/.ssh/id_ed25519)
#   3 - file permissions (e.g., 600)
# Environment:
#   AGE_PASSPHRASE - the decryption passphrase (piped to age via stdin)
# Returns:
#   0 on success, 1 on failure
#######################################
secrets::decrypt_file() {
  local src="$1" dest="$2" perms="$3"

  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) decrypt ${src} → ${dest}"
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"

  if printf '%s' "${AGE_PASSPHRASE}" | age -d -o "${dest}.tmp" "${src}" 2> /dev/null; then
    mv "${dest}.tmp" "${dest}"
    chmod "${perms}" "${dest}"
    return 0
  fi

  rm -f "${dest}.tmp"
  return 1
}

#######################################
# secrets::decrypt_all
# Decrypt all secrets from the manifest file.
# The manifest (secrets/manifest.txt) maps encrypted files to destinations:
#   ssh_id_ed25519.age:~/.ssh/id_ed25519:600
#   ssh_id_ed25519.pub.age:~/.ssh/id_ed25519.pub:644
#   gpg_private.age:~/.gnupg/private-key.asc:600
# Globals:
#   SECRETS_DIR
# Returns:
#   0 if all succeeded, 1 if any failed
#######################################
secrets::decrypt_all() {
  local manifest="${SECRETS_DIR}/manifest.txt"
  if [[ ! -f "${manifest}" ]]; then
    warn "No secrets manifest found at ${manifest}"
    return 1
  fi

  local passphrase
  passphrase="$(secrets::prompt_passphrase)" || return 1
  export AGE_PASSPHRASE="${passphrase}"

  local line src dest perms encrypted_file failed=0
  while IFS=: read -r src dest perms; do
    # Skip comments and blank lines
    [[ -z "${src}" || "${src}" == \#* ]] && continue

    # Expand ~ to HOME
    dest="${dest/#\~/${HOME}}"
    encrypted_file="${SECRETS_DIR}/${src}"

    if [[ ! -f "${encrypted_file}" ]]; then
      warn "Encrypted file missing: ${encrypted_file}"
      failed=1
      continue
    fi

    step "Decrypting ${src}"
    fs::backup "${dest}"
    if secrets::decrypt_file "${encrypted_file}" "${dest}" "${perms}"; then
      success "${src} → ${dest}"
    else
      error "Failed to decrypt ${src} (wrong passphrase?)"
      failed=1
    fi
  done < "${manifest}"

  unset AGE_PASSPHRASE
  return "${failed}"
}

#######################################
# secrets::encrypt_file
# Encrypt a file with age passphrase encryption.
# Arguments:
#   1 - source file path
#   2 - output .age file path
# Outputs:
#   Prompts for passphrase via age
# Returns:
#   0 on success, 1 on failure
#######################################
secrets::encrypt_file() {
  local src="$1" dest="$2"
  if [[ ! -f "${src}" ]]; then
    error "Source file not found: ${src}"
    return 1
  fi
  age -p -o "${dest}" "${src}"
}

#######################################
# secrets::setup
# Main orchestrator for secrets decryption during install.
# Outputs:
#   Headline and delegated messages
#######################################
secrets::setup() {
  headline "Secrets"
  secrets::install_age

  if ! secrets::has_encrypted_files; then
    note "No encrypted secrets found — skipping"
    note "To add secrets, see: ${SECRETS_DIR}/README.md"
    return 0
  fi

  info "Encrypted secrets detected in ${SECRETS_DIR}"

  if core::have gum; then
    if ! gum confirm "Decrypt secrets now?"; then
      note "Skipped — re-run the installer later to decrypt"
      return 0
    fi
  fi

  step "Decrypting secrets"
  if secrets::decrypt_all; then
    success "All secrets decrypted"
  else
    warn "Some secrets failed to decrypt — you can re-run the installer later"
  fi
}
