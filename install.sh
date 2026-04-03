#!/bin/bash
# Dotfiles / Dev Environment Installer (modular edition)
set -Eeuo pipefail
IFS=$'\n\t'

readonly DOTFILES_REPO="https://github.com/dipodidae/dotfiles.git"
readonly DOTFILES_CLONE_DIR="${HOME}/clones/dotfiles"

#######################################
# bootstrap
# When running from a curl pipe (no local repo), install minimal prereqs,
# clone the repo, and re-exec the cloned installer.
# This ensures every install runs from a local clone with symlinks.
#######################################
bootstrap() {
  printf '\033[1m%s\033[0m\n' "Bootstrapping dotfiles installer..."

  # Install git if missing (need it to clone)
  if ! command -v git > /dev/null 2>&1; then
    printf '▶ Installing git...\n'
    if command -v apt-get > /dev/null 2>&1; then
      sudo apt-get update -y && sudo apt-get install -y git
    elif command -v dnf > /dev/null 2>&1; then
      sudo dnf install -y git
    elif command -v yum > /dev/null 2>&1; then
      sudo yum install -y git
    elif command -v pacman > /dev/null 2>&1; then
      sudo pacman -S --noconfirm git
    elif command -v brew > /dev/null 2>&1; then
      brew install git
    else
      printf 'ERROR: Cannot install git automatically. Install git and re-run.\n' >&2
      exit 1
    fi
  fi

  # Clone or update the dotfiles repo
  mkdir -p "$(dirname "${DOTFILES_CLONE_DIR}")"
  if [[ -d "${DOTFILES_CLONE_DIR}/.git" ]]; then
    printf '▶ Updating existing dotfiles clone...\n'
    git -C "${DOTFILES_CLONE_DIR}" pull -q || true
  else
    printf '▶ Cloning dotfiles to %s...\n' "${DOTFILES_CLONE_DIR}"
    git clone "${DOTFILES_REPO}" "${DOTFILES_CLONE_DIR}"
  fi

  printf '▶ Handing off to cloned installer...\n\n'
  exec "${DOTFILES_CLONE_DIR}/install.sh" "$@"
}

# Detect if running from curl pipe or outside the repo — bootstrap if so
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2> /dev/null && pwd || echo "")"
if [[ -z "${SCRIPT_DIR}" || ! -d "${SCRIPT_DIR}/.git" ]]; then
  bootstrap "$@"
fi

readonly SCRIPT_DIR
readonly LOG_FILE="${HOME}/.dotfiles-install.log"
readonly BACKUP_DIR="${HOME}/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
readonly DOTFILES_NVM_VERSION="v0.40.3"

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

readonly MODULES=(logging core fs pkg python node dev_tools zsh secrets system)
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
_fail_lineno=""
#######################################
# cleanup
# Trap handler that reports failure context and surfaces backup/log info.
# Globals:
#   BACKUP_DIR
#   LOG_FILE
#   _fail_line (modified)
#   _fail_lineno (modified)
# Arguments: none
# Returns:
#   Exits with original shell status
#######################################
cleanup() {
  local rc=$?
  if ((rc != 0)); then
    error "Aborted (exit ${rc}) at ${BASH_SOURCE[0]}:${_fail_lineno} ${_fail_line}"
    error "See log: ${LOG_FILE}"
    if [[ -d ${BACKUP_DIR} ]]; then
      info "Backups: ${BACKUP_DIR}"
    fi
  fi
  exit "${rc}"
}
trap cleanup EXIT
trap '_fail_line="(last cmd: $BASH_COMMAND)"; _fail_lineno="${LINENO}"' DEBUG

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

# Install gum first so all output is styled from the start.
dev_tools::ensure_gum

if core::have gum; then
  printf "\n"
  gum style --bold --foreground 212 --border double \
    --border-foreground 99 --align center --padding "1 4" \
    --margin "0 2" \
    "  dotfiles  " \
    "" \
    "github.com/dipodidae/dotfiles"
  printf "\n"
else
  info "Detected OS: ${OS_TYPE}"
fi

main() {
  headline "Initialize"
  core::require_internet
  system::install_base
  zsh::setup
  node::setup
  python::setup
  zsh::apply_dotfiles
  dev_tools::setup
  secrets::setup
  zsh::ensure_default_shell
  system::self_test
  system::summary

  if core::have gum; then
    printf "\n"
    gum style --bold --foreground 78 --border rounded \
      --border-foreground 78 --align center --padding "0 3" \
      "✔ Installation complete"
    printf "\n"
  else
    success "Installation complete"
  fi
}

main "$@"
