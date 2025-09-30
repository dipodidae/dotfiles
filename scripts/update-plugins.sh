#!/bin/bash
# Refresh custom Oh My Zsh plugins from the local dotfiles repository.

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DEFAULT_LOG_FILE="${HOME}/.dotfiles-plugin-update.log"
LOG_FILE="${DEFAULT_LOG_FILE}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly C_RESET='\033[0m'
  readonly C_DIM='\033[2m'
  readonly C_RED='\033[31m'
  readonly C_GREEN='\033[32m'
  readonly C_YELLOW='\033[33m'
  readonly C_BLUE='\033[34m'
  readonly C_MAGENTA='\033[35m'
  readonly C_CYAN='\033[36m'
  readonly C_BOLD='\033[1m'
else
  readonly C_RESET=""
  readonly C_DIM=""
  readonly C_RED=""
  readonly C_GREEN=""
  readonly C_YELLOW=""
  readonly C_BLUE=""
  readonly C_MAGENTA=""
  readonly C_CYAN=""
  readonly C_BOLD=""
fi

DRY_RUN="0"

#######################################
# Print command usage help text.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Usage information on stdout.
# Returns:
#   0 always.
#######################################
usage() {
  cat << 'EOF'
Usage: scripts/update-plugins.sh [--dry-run] [--help]
Synchronize custom Oh My Zsh plugins from the local dotfiles repository.

Options:
  --dry-run       Show actions without copying files
  -h, --help      Display this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN="1"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "${DRY_RUN}" == "1" ]]; then
  LOG_FILE="/dev/null"
else
  [[ -f "${LOG_FILE}" ]] || : > "${LOG_FILE}"
fi
readonly LOG_FILE

modules=(logging core fs zsh)
for module in "${modules[@]}"; do
  module_path="${SCRIPT_DIR}/lib/${module}.sh"
  if [[ ! -f "${module_path}" ]]; then
    printf 'Required module missing: %s\n' "${module_path}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  . "${module_path}"
done

#######################################
# Trap handler that logs completion status and errors.
# Globals:
#   LOG_FILE
# Outputs:
#   Logs success or failure messaging.
# Returns:
#   Propagates the existing exit code.
#######################################
cleanup() {
  local rc=$?
  if ((rc != 0)); then
    if [[ "${DRY_RUN}" == "1" ]]; then
      error "Plugin update failed (exit ${rc})."
    else
      error "Plugin update failed (exit ${rc}). See ${LOG_FILE}."
    fi
  else
    if [[ "${DRY_RUN}" == "1" ]]; then
      note "(dry-run) No log file written."
    else
      note "Log written to ${LOG_FILE}."
    fi
  fi
}
trap cleanup EXIT

#######################################
# update_custom_plugin
# Trigger installer for a custom plugin with force refresh.
# Arguments:
#   1 - Plugin slug (directory name).
#   2 - Installer function name.
#   3 - Base plugins directory.
# Returns:
#   0 on success, 1 on failure.
#######################################
update_custom_plugin() {
  local slug="$1" installer="$2" base="$3"

  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) Would refresh ${slug}"
    return 0
  fi

  if "$installer" "${base}" 1; then
    return 0
  fi

  warn "${slug} refresh failed"
  return 1
}

main() {
  if core::is_remote_install; then
    die "This script must be run from a local clone with a .git directory present."
  fi

  headline "Update custom zsh plugins"

  if [[ "${DRY_RUN}" == "1" ]]; then
    note "Dry-run mode: no filesystem changes will be made."
  fi

  local base="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"
  fs::ensure_dir "${base}"

  local -A installers=(
    ["spend-cloud"]=zsh::install_spend_cloud_plugin
    ["ssh-transfer"]=zsh::install_ssh_transfer_plugin
    ["remote-prepare"]=zsh::install_remote_prepare_plugin
  )
  local -a plugins=("spend-cloud" "ssh-transfer" "remote-prepare")

  local plugin installer
  local -i failures=0
  for plugin in "${plugins[@]}"; do
    installer="${installers[${plugin}]:-}"
    if [[ -z "${installer}" ]]; then
      warn "No installer registered for ${plugin}"
      ((failures++))
      continue
    fi
    if ! update_custom_plugin "${plugin}" "${installer}" "${base}"; then
      ((failures++))
    fi
  done

  if ((failures > 0)); then
    warn "Completed with ${failures} failure(s)."
    return 1
  fi

  success "Custom plugins synchronized"
  return 0
}

main "$@"
