#!/usr/bin/env zsh
#
# ssh-transfer plugin: copy local SSH key pairs to a remote ~/.ssh directory
# without overwriting existing files. Provides the `transfer-ssh-keys` command.

# Guard against duplicate sourcing
if [[ -n "${_SSH_TRANSFER_PLUGIN_LOADED:-}" ]]; then
  return 0
fi
typeset -g _SSH_TRANSFER_PLUGIN_LOADED=1

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

  local -n out_ref="$1"
  local key_dir="${HOME}/.ssh"
  local -a privates publics seen

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

  out_ref=( "${(@)privates}" "${(@)publics}" )
  return 0
}

_ssh_transfer_plugin::build_ssh_cmd() {
  emulate -L zsh
  setopt local_options pipefail
  local -n out_ref="$1"
  local remote="$2" port="$3"

  out_ref=(ssh -o BatchMode=no)
  (( port != 22 )) && out_ref+=(-p "${port}")
  out_ref+=("${remote}")
}

_ssh_transfer_plugin::remote_exec() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" port="$2" command="$3"
  local -a ssh_cmd
  _ssh_transfer_plugin::build_ssh_cmd ssh_cmd "${remote}" "${port}"
  ssh_cmd+=("${command}")
  "${ssh_cmd[@]}"
}

_ssh_transfer_plugin::remote_exists() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" port="$2" target="$3"
  _ssh_transfer_plugin::remote_exec "${remote}" "${port}" "test -e ${target}"
}

_ssh_transfer_plugin::set_remote_permissions() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" port="$2" filename="$3"
  local mode=600
  [[ "${filename}" == *.pub ]] && mode=644
  _ssh_transfer_plugin::remote_exec "${remote}" "${port}" "chmod ${mode} ~/.ssh/${filename}"
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
    local file
    for file in "${key_files[@]}"; do
      printf '  • %s\n' "${file}"
    done
    return 0
  fi

  if ! _ssh_transfer_plugin::remote_exec "${remote}" "${port}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"; then
    _ssh_transfer_plugin::log_error "Failed to prepare remote ~/.ssh directory"
    return 1
  fi

  local -a scp_base=(scp -p -q)
  (( port != 22 )) && scp_base+=(-P "${port}")

  local file base remote_target copied_any=0
  for file in "${key_files[@]}"; do
    base="${file##*/}"
    remote_target="~/.ssh/${base}"
    if _ssh_transfer_plugin::remote_exists "${remote}" "${port}" "${remote_target}"; then
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
