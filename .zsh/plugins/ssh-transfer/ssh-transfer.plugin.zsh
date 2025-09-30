#!/usr/bin/env zsh
#
# ssh-transfer plugin: copy local SSH key pairs to a remote ~/.ssh directory
# without overwriting existing files. Provides the `transfer-ssh-keys` command.

# Guard against duplicate sourcing
if [[ -n "${_SSH_TRANSFER_PLUGIN_LOADED:-}" ]]; then
  return 0
fi
typeset -g _SSH_TRANSFER_PLUGIN_LOADED=1

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  typeset -g _SSH_TRANSFER_COLOR_RESET=$'\033[0m'
  typeset -g _SSH_TRANSFER_COLOR_DIM=$'\033[2m'
  typeset -g _SSH_TRANSFER_COLOR_HEADER=$'\033[38;5;45m'
  typeset -g _SSH_TRANSFER_COLOR_NAME=$'\033[1;36m'
  typeset -g _SSH_TRANSFER_COLOR_PRIVATE=$'\033[38;5;83m'
  typeset -g _SSH_TRANSFER_COLOR_PUBLIC=$'\033[38;5;207m'
else
  typeset -g _SSH_TRANSFER_COLOR_RESET=""
  typeset -g _SSH_TRANSFER_COLOR_DIM=""
  typeset -g _SSH_TRANSFER_COLOR_HEADER=""
  typeset -g _SSH_TRANSFER_COLOR_NAME=""
  typeset -g _SSH_TRANSFER_COLOR_PRIVATE=""
  typeset -g _SSH_TRANSFER_COLOR_PUBLIC=""
fi

# ────────────────────────────────────────────────────────────────────────────────
# INTERNAL HELPERS
# ────────────────────────────────────────────────────────────────────────────────

_ssh_transfer_plugin::log_info() {
  printf 'ℹ️  %s\n' "$*"
}

_ssh_transfer_plugin::log_success() {
  printf '✅ %s\n' "$*"
}

_ssh_transfer_plugin::log_warn() {
  printf '⚠️  %s\n' "$*" >&2
}

_ssh_transfer_plugin::log_error() {
  printf '❌ %s\n' "$*" >&2
}

_ssh_transfer_plugin::print_pair_block() {
  emulate -L zsh
  setopt local_options pipefail

  local key_name="$1" private_path="$2" public_path="$3"

  printf '%s⌈ %s%s%s ⌉%s\n' \
    "${_SSH_TRANSFER_COLOR_HEADER}" \
    "${_SSH_TRANSFER_COLOR_NAME}" "${key_name}" "${_SSH_TRANSFER_COLOR_HEADER}" \
    "${_SSH_TRANSFER_COLOR_RESET}"

  if [[ -n "${private_path}" ]]; then
    printf '%s⌊ %s%-4s%s → %s%s%s ⌋%s\n' \
      "${_SSH_TRANSFER_COLOR_PRIVATE}" \
      "${_SSH_TRANSFER_COLOR_DIM}" "priv" "${_SSH_TRANSFER_COLOR_PRIVATE}" \
      "${_SSH_TRANSFER_COLOR_DIM}" "${private_path}" "${_SSH_TRANSFER_COLOR_PRIVATE}" \
      "${_SSH_TRANSFER_COLOR_RESET}"
  fi

  if [[ -n "${public_path}" ]]; then
    printf '%s⌊ %s%-4s%s → %s%s%s ⌋%s\n' \
      "${_SSH_TRANSFER_COLOR_PUBLIC}" \
      "${_SSH_TRANSFER_COLOR_DIM}" "pub" "${_SSH_TRANSFER_COLOR_PUBLIC}" \
      "${_SSH_TRANSFER_COLOR_DIM}" "${public_path}" "${_SSH_TRANSFER_COLOR_PUBLIC}" \
      "${_SSH_TRANSFER_COLOR_RESET}"
  fi

  printf '\n'
}

_ssh_transfer_plugin::print_key_summary() {
  emulate -L zsh
  setopt local_options pipefail

  local -a files
  files=("$@")

  if (( ${#files} == 0 )); then
    return 0
  fi

  typeset -A priv_map
  typeset -A pub_map

  local file base key
  for file in "${files[@]}"; do
    base="${file##*/}"
    if [[ "${base}" == *.pub ]]; then
      key="${base%.pub}"
      pub_map["${key}"]="${file}"
    else
      key="${base}"
      priv_map["${key}"]="${file}"
    fi
  done

  local -a combined_keys
  combined_keys=( "${(@k)priv_map}" "${(@k)pub_map}" )
  combined_keys=( "${(@u)combined_keys}" )
  combined_keys=( "${(@on)combined_keys}" )

  local key_name
  for key_name in "${combined_keys[@]}"; do
    local display_name="${key_name}"
    display_name="${display_name#\"}"
    display_name="${display_name%\"}"

    _ssh_transfer_plugin::print_pair_block \
      "${display_name}" \
      "${priv_map[$key_name]:-}" \
      "${pub_map[$key_name]:-}"
  done
}

_ssh_transfer_plugin::usage() {
  cat <<'EOF'
Usage: transfer-ssh-keys <user@host> [options]
Options:
  -p, --port <port>   SSH port (default: 22)
      --dry-run       Show actions without copying
  -h, --help          Display this help message

Copies local SSH key pairs from ~/.ssh to the remote ~/.ssh directory without
overwriting existing files. Only private/public key pairs are transferred.
EOF
}

_ssh_transfer_plugin::collect_keys() {
  emulate -L zsh
  setopt local_options null_glob pipefail

  local out_name="$1"
  local key_dir="${HOME}/.ssh"
  typeset -a privates publics seen

  if [[ ! -d "${key_dir}" ]]; then
    _ssh_transfer_plugin::log_error "Local ~/.ssh directory not found"
    return 1
  fi

  local pub base private candidate
  for pub in "${key_dir}"/*.pub(N); do
    [[ -f "${pub}" ]] || continue
    publics+=("${pub}")
    base="${pub%.pub}"
    if [[ -f "${base}" ]]; then
      privates+=("${base}")
      seen+=("${base}")
    fi
  done

  for candidate in "${key_dir}"/id_*(N) "${key_dir}"/*.key(N) "${key_dir}"/*.pem(N); do
    [[ -f "${candidate}" ]] || continue
    if printf '%s' "${candidate}" | grep -Eq '\.(pub|bak|old)$'; then
      continue
    fi
    if grep -Eq 'BEGIN (OPENSSH|RSA|DSA|EC|ED25519) PRIVATE KEY' "${candidate}" 2> /dev/null; then
      local already=0 existing
      for existing in "${seen[@]}"; do
        if [[ "${existing}" == "${candidate}" ]]; then
          already=1
          break
        fi
      done
      (( already == 0 )) && privates+=("${candidate}")
    fi
  done

  if (( ${#privates} == 0 && ${#publics} == 0 )); then
    _ssh_transfer_plugin::log_warn "No SSH keys found in ${key_dir}"
    return 1
  fi

  set -A "${out_name}" "${(@)privates}" "${(@)publics}"
  return 0
}

_ssh_transfer_plugin::build_ssh_cmd() {
  emulate -L zsh
  setopt local_options pipefail
  local out_name="$1"
  local remote="$2" port="$3"
  local -a assembled=(ssh -o BatchMode=no)

  (( port != 22 )) && assembled+=(-p "${port}")
  assembled+=("${remote}")

  set -A "${out_name}" -- "${assembled[@]}"
}

_ssh_transfer_plugin::remote_exec() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" port="$2"
  shift 2
  local -a ssh_cmd
  _ssh_transfer_plugin::build_ssh_cmd ssh_cmd "${remote}" "${port}"
  if (( $# > 0 )); then
    ssh_cmd+=("$@")
  fi
  "${ssh_cmd[@]}"
}

_ssh_transfer_plugin::remote_exists() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" port="$2" filename="$3"
  local remote_cmd
  printf -v remote_cmd 'test -e "$HOME/.ssh/%s"' "${filename}"
  _ssh_transfer_plugin::remote_exec "${remote}" "${port}" sh -c "${remote_cmd}"
}

_ssh_transfer_plugin::set_remote_permissions() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" port="$2" filename="$3"
  local mode=600
  [[ "${filename}" == *.pub ]] && mode=644
  local remote_cmd
  printf -v remote_cmd 'chmod %d "$HOME/.ssh/%s"' "${mode}" "${filename}"
  _ssh_transfer_plugin::remote_exec "${remote}" "${port}" sh -c "${remote_cmd}"
}

# ────────────────────────────────────────────────────────────────────────────────
# PUBLIC COMMAND
# ────────────────────────────────────────────────────────────────────────────────

transfer_ssh_keys() {
  emulate -L zsh
  setopt local_options pipefail

  local port=22 dry_run=0
  local -a positional

  while (( $# )); do
    case "$1" in
      -p|--port)
        if [[ -n "${2:-}" ]]; then
          port="$2"
          shift 2
          continue
        fi
        _ssh_transfer_plugin::log_error "Missing value for $1"
        return 2
        ;;
      --dry-run)
        dry_run=1
        shift
        continue
        ;;
      -h|--help)
        _ssh_transfer_plugin::usage
        return 0
        ;;
      --)
        shift
        positional+=("$@")
        break
        ;;
      -*)
        _ssh_transfer_plugin::log_error "Unknown option: $1"
        _ssh_transfer_plugin::usage
        return 2
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  if (( ${#positional} == 0 )); then
    _ssh_transfer_plugin::usage >&2
    return 2
  fi

  local remote="${positional[1]}"
  if [[ "${remote}" != *"@"* ]]; then
    _ssh_transfer_plugin::log_warn "Remote should include user (example: user@host)"
  fi

  local cmd
  for cmd in ssh scp; do
    if ! command -v "${cmd}" > /dev/null 2>&1; then
      _ssh_transfer_plugin::log_error "Required command not found: ${cmd}"
      return 127
    fi
  done

  local -a key_files
  if ! _ssh_transfer_plugin::collect_keys key_files; then
    return 1
  fi

  if (( dry_run )); then
    _ssh_transfer_plugin::log_info "Dry run: would transfer the following keys to ${remote}:"
    _ssh_transfer_plugin::print_key_summary "${key_files[@]}"
    return 0
  fi

    _ssh_transfer_plugin::log_info "Preparing to transfer the following keys to ${remote}:"
    _ssh_transfer_plugin::print_key_summary "${key_files[@]}"

  local prepare_cmd='umask 077 && mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"'
  if ! _ssh_transfer_plugin::remote_exec "${remote}" "${port}" sh -c "${prepare_cmd}"; then
    _ssh_transfer_plugin::log_error "Failed to prepare remote ~/.ssh directory"
    return 1
  fi

  local -a scp_base=(scp -p -q)
  (( port != 22 )) && scp_base+=(-P "${port}")

  local file base remote_target copied_any=0
  for file in "${key_files[@]}"; do
    base="${file##*/}"
    if [[ "${base}" == *[^[:alnum:]._-]* ]]; then
      _ssh_transfer_plugin::log_warn "Skipping ${base} (unsupported characters in filename)"
      continue
    fi

    remote_target="~/.ssh/${base}"
    if _ssh_transfer_plugin::remote_exists "${remote}" "${port}" "${base}"; then
      _ssh_transfer_plugin::log_warn "Skipping ${base} (already exists on remote)"
      continue
    fi

    if ! "${scp_base[@]}" "${file}" "${remote}:${remote_target}"; then
      _ssh_transfer_plugin::log_error "Copy failed for ${file}"
      return 1
    fi

    if ! _ssh_transfer_plugin::set_remote_permissions "${remote}" "${port}" "${base}"; then
      _ssh_transfer_plugin::log_warn "Unable to set permissions for ${base} on remote"
    fi

    copied_any=1
    _ssh_transfer_plugin::log_info "Transferred ${base}"
  done

  if (( copied_any == 0 )); then
    _ssh_transfer_plugin::log_warn "No keys were copied (all files already exist on remote)"
  else
    _ssh_transfer_plugin::log_success "SSH key transfer complete"
  fi
}

alias transfer-ssh-keys='transfer_ssh_keys'
