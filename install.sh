#!/bin/bash
# Dotfiles / Dev Environment Installer (modular edition)
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${HOME}/.dotfiles-install.log"
readonly BACKUP_DIR="${HOME}/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
readonly NVM_VERSION="v0.40.3"
readonly DOTFILES_RAW="https://raw.githubusercontent.com/dipodidae/dotfiles/main"

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

readonly MODULES=(logging core fs pkg python node dev_tools zsh system)
for module in "${MODULES[@]}"; do
  module_path="${SCRIPT_DIR}/lib/${module}.sh"
  if [[ ! -f "${module_path}" ]]; then
    printf 'ERROR: required module "%s" missing (%s)\n' "${module}" "${module_path}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  . "${module_path}"
done

[[ -f "${LOG_FILE}" ]] || : > "${LOG_FILE}"

_fail_line=""
#######################################
# cleanup
# Trap handler that reports failure context and surfaces backup/log info.
# Globals:
#   BACKUP_DIR
#   LOG_FILE
#   _fail_line (modified)
# Arguments: none
# Returns:
#   Exits with original shell status
#######################################
cleanup() {
  local rc=$?
  if ((rc != 0)); then
    error "Aborted (exit ${rc}) at ${BASH_SOURCE[0]}:${LINENO} ${_fail_line}"
    error "See log: ${LOG_FILE}"
    if [[ -d ${BACKUP_DIR} ]]; then
      info "Backups: ${BACKUP_DIR}"
    fi
  fi
  exit "${rc}"
}
trap cleanup EXIT
trap '_fail_line="(last cmd: $BASH_COMMAND)"' DEBUG

DRY_RUN="0"
SKIP_PACKAGES="0"
SKIP_PYTHON="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN="1"
      ;;
    --skip-packages)
      SKIP_PACKAGES="1"
      ;;
    --skip-python)
      SKIP_PYTHON="1"
      ;;
    -h | --help)
      cat << EOF
Dotfiles / Dev Environment Installer (modular edition)
Usage: $0 [--dry-run] [--skip-packages] [--help]
    --dry-run        Show actions only
    --skip-packages  Skip system package manager steps
    --skip-python    Skip pyenv/Python installation
EOF
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift

done

readonly DRY_RUN SKIP_PACKAGES SKIP_PYTHON

if [[ "${DRY_RUN}" == "1" ]]; then
  note "(dry-run mode) No changes will be made."
fi

readonly OS_TYPE="$(core::detect_os)"
if [[ "${OS_TYPE}" == "unknown" ]]; then
  die "Unsupported OS"
fi
info "Detected OS: ${OS_TYPE}"

main() {
  headline "Initialize"
  core::require_internet
  system::install_base
  zsh::setup
  node::setup
  python::setup
  zsh::apply_dotfiles
  dev_tools::setup
  zsh::ensure_default_shell
  system::self_test
  system::summary
  success "Installation complete"
}

main "$@"
