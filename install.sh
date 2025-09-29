#!/bin/bash
#
# Dotfiles / Dev Environment Installer (Simplified, Robust, DRY)
#
# Recreates the functionality of the previous large installer with a
# cleaner structure, modern logging, and stronger error handling.

set -Eeuo pipefail
IFS=$'\n\t'

# NOTE: Gradual refactor in progress. Some functionality will move into lib/*.sh
# modules for readability and testability. Sourced below if present.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${HOME}/.dotfiles-install.log"
readonly BACKUP_DIR="${HOME}/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
readonly NVM_VERSION="v0.40.3"
readonly DOTFILES_RAW="https://raw.githubusercontent.com/dipodidae/dotfiles/main"

# Colors (auto-disable if not a TTY or NO_COLOR set)
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

# Module sourcing ------------------------------------------------------------
#######################################
# Module sourcing
# Prefer local lib/*.sh modules. If the script is being executed via the
# remote curl | bash method (no local git checkout and missing module),
# fetch the module from the remote repository raw URL into a temp file
# and source it. This keeps feature parity for remote installs.
# Globals:
#   SCRIPT_DIR, DOTFILES_RAW, TMPDIR
# Arguments:
#   None
#######################################
readonly MODULE_LIST=(logging pkg node python zsh_setup)
for mod in "${MODULE_LIST[@]}"; do
  local_path="${SCRIPT_DIR}/lib/${mod}.sh"
  if [[ -f "${local_path}" ]]; then
    # shellcheck disable=SC1090
    . "${local_path}"
    continue
  fi
  # Remote fallback: only attempt if not a git checkout (curl mode)
  if [[ ! -d "${SCRIPT_DIR}/.git" ]]; then
    tmp_mod="${TMPDIR:-/tmp}/dotfiles-${mod}.sh"
    if curl -fsSL "${DOTFILES_RAW}/lib/${mod}.sh" -o "${tmp_mod}"; then
      # shellcheck disable=SC1090
      . "${tmp_mod}"
    else
      echo "WARN: unable to load module '${mod}' from remote" >&2
    fi
  fi
done
unset mod local_path tmp_mod

# Trap / error context --------------------------------------------------------
_fail_line=""
#######################################
# Cleanup function called on script exit
# Globals:
#   BACKUP_DIR, LOG_FILE, _fail_line
# Arguments:
#   None
# Returns:
#   Exits with the original script exit code
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

# CLI options -----------------------------------------------------------------
DRY_RUN="0"
SKIP_PACKAGES="0"
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN="1" ;;
    --skip-packages) SKIP_PACKAGES="1" ;;
    -h | --help)
      cat << EOF
Dotfiles / Dev Environment Installer (clean edition)
Usage: $0 [--dry-run] [--skip-packages] [--help]
    --dry-run        Show actions only
    --skip-packages  Skip system package manager steps
EOF
      exit 0
      ;;
    *) die "Unknown option: ${arg}" ;;
  esac
done

readonly DRY_RUN SKIP_PACKAGES

if [[ "${DRY_RUN}" == "1" ]]; then
  printf '%s\n' "(dry-run mode) No changes will be made." | tee -a "${LOG_FILE}" > /dev/null
fi

[[ -f "${LOG_FILE}" ]] || : > "${LOG_FILE}"

# Helpers ---------------------------------------------------------------------
#######################################
# Execute a command (respecting DRY_RUN mode)
# Globals:
#   DRY_RUN
# Arguments:
#   Command + arguments to execute
# Returns:
#   Exit status of command or 0 in DRY_RUN mode
#######################################
run() {
  if [[ "${DRY_RUN}" == 1 ]]; then
    note "(dry-run) $*"
    return 0
  fi
  "$@"
}

#######################################
# Check if a command exists
# Arguments:
#   $1 - command name to check
# Returns:
#   0 if command exists, 1 otherwise
#######################################
have() {
  command -v "$1" > /dev/null 2>&1
}

#######################################
# Check if this is a remote install (not a git checkout)
# Globals:
#   SCRIPT_DIR
# Returns:
#   0 if remote install, 1 if git checkout
#######################################
remote_install() {
  [[ ! -d "${SCRIPT_DIR}/.git" ]]
}

#######################################
# Download a file (with retries) from repository raw path
# Globals:
#   DOTFILES_RAW, DRY_RUN
# Arguments:
#   $1 - relative remote path
#   $2 - destination path
# Outputs:
#   Writes file to destination on success
# Returns:
#   0 on success, non-zero on failure
#######################################
download() {
  local src="${DOTFILES_RAW}/$1" dest="$2"
  local tries=0
  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) download ${src} -> ${dest}"
    : > "${dest}"
    return 0
  fi
  while ((tries < 3)); do
    if curl -fsSL "${src}" -o "${dest}"; then
      return 0
    fi
    ((tries++))
    sleep 1
  done
  return 1
}

#######################################
# Copy a file or directory into BACKUP_DIR (created lazily)
# Globals:
#   BACKUP_DIR
# Arguments:
#   $1 - file or directory path
# Returns:
#   0 always (warns on failure)
#######################################
backup() {
  local f="$1"
  [[ -e "${f}" ]] || return 0
  mkdir -p "${BACKUP_DIR}"
  if cp -a "${f}" "${BACKUP_DIR}/"; then
    note "Backup: $(basename "${f}")"
  else
    warn "Backup failed: ${f}"
  fi
}

#######################################
# Detect the current operating system family
# Outputs:
#   Prints an identifier for the current OS family
# Returns:
#   0 (always) - result via stdout
#######################################
detect_os() {
  if [[ "${OSTYPE}" == linux-* ]]; then
    if have apt; then
      echo debian
    elif have dnf || have yum; then
      echo redhat
    elif have pacman; then
      echo arch
    else
      echo linux
    fi
  elif [[ "${OSTYPE}" == darwin* ]]; then
    echo macos
  else
    echo unknown
  fi
}

#######################################
# Simple network reachability check against github.com
# Returns:
#   Exits script on failure
#######################################
require_internet() {
  step "Checking internet"
  curl -fsSL https://github.com > /dev/null || die "No internet connectivity"
  success "Network OK"
}

# Package installation abstraction -------------------------------------------
readonly OS_TYPE="$(detect_os)"
[[ "${OS_TYPE}" == unknown ]] && die "Unsupported OS"
info "Detected OS: ${OS_TYPE}"

#######################################
# Run apt-get update at most once per execution
# Globals:
#   _APT_UPDATED
#######################################
apt_update_once() {
  if [[ "${_APT_UPDATED:-0}" == "0" ]]; then
    run sudo apt-get update -y
    _APT_UPDATED="1"
  fi
}

#######################################
# Install a list of packages using the native package manager
# Globals:
#   OS_TYPE
# Arguments:
#   Package names (variadic)
#######################################
pkg_install() {
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  case "${OS_TYPE}" in
    debian)
      apt_update_once
      run sudo apt-get install -y "${pkgs[@]}"
      ;;
    redhat)
      if have dnf; then
        run sudo dnf install -y "${pkgs[@]}"
      else
        run sudo yum install -y "${pkgs[@]}"
      fi
      ;;
    arch)
      run sudo pacman -S --noconfirm --needed "${pkgs[@]}"
      ;;
    macos)
      have brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null
      run brew install "${pkgs[@]}"
      ;;
    *)
      warn "Automatic package install unsupported for: ${OS_TYPE}"
      return 0
      ;;
  esac
}

#######################################
# Wrapper around pkg_install with logging suitable for grouped installs
# Arguments:
#   $1 - label
#   Remaining args - packages
#######################################
ensure_pkgs() {
  local label="$1"
  shift
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  step "Installing ${label} (${pkgs[*]})"
  if pkg_install "${pkgs[@]}"; then
    success "${label} ready"
  else
    warn "${label} partial/failed"
  fi
}

#######################################
# Install build dependencies required for compiling Python via pyenv
# Globals:
#   OS_TYPE
#######################################
install_python_build_deps() {
  case "${OS_TYPE}" in
    debian)
      ensure_pkgs "python build deps" \
        build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev \
        libxmlsec1-dev libffi-dev liblzma-dev
      ;;
    redhat)
      if have dnf; then
        pkg_install gcc gcc-c++ make openssl-devel bzip2 bzip2-devel \
          libffi-devel zlib-devel readline-devel sqlite sqlite-devel xz \
          xz-devel tk tk-devel || true
      else
        pkg_install gcc gcc-c++ make openssl-devel bzip2 bzip2-devel \
          libffi-devel zlib-devel readline-devel sqlite sqlite-devel xz \
          xz-devel tk tk-devel || true
      fi
      ;;
    arch)
      ensure_pkgs "python build deps" base-devel openssl zlib xz tk || true
      ;;
    macos)
      # Xcode CLT required
      if ! xcode-select -p > /dev/null 2>&1; then
        step "Installing Xcode Command Line Tools"
        xcode-select --install || true
      fi
      ;;
    *)
      warn "Skipping automatic Python build deps for ${OS_TYPE}"
      ;;
  esac
}

# Specific component installers ----------------------------------------------
#######################################
# Install a minimal set of base packages
# Globals:
#   SKIP_PACKAGES, OS_TYPE
#######################################
install_base() {
  if [[ "${SKIP_PACKAGES}" == "1" ]]; then
    info "Skipping base packages"
    return 0
  fi
  headline "Base Packages"
  case "${OS_TYPE}" in
    debian) ensure_pkgs base zsh git curl wget ca-certificates gnupg lsb-release ;;
    redhat) ensure_pkgs base zsh git curl wget ca-certificates gnupg ;;
    arch) ensure_pkgs base zsh git curl wget ;;
    macos) ensure_pkgs base zsh git curl wget ;;
    *) warn "Manual install required: zsh git curl wget" ;;
  esac
}

#######################################
# Install GitHub CLI appropriate to the platform
# Globals:
#   OS_TYPE
#######################################
install_gh_cli() {
  headline "GitHub CLI"
  if have gh; then
    note "gh already present ($(gh --version | head -n1))"
    return 0
  fi
  case "${OS_TYPE}" in
    debian)
      apt_update_once
      run sudo mkdir -p /etc/apt/keyrings
      run bash -c 'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null'
      run sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      run bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null'
      apt_update_once
      pkg_install gh
      ;;
    redhat) pkg_install gh || warn "Install gh manually: https://cli.github.com" ;;
    arch) pkg_install github-cli ;;
    macos) pkg_install gh ;;
    *) warn "Install gh manually" ;;
  esac
  if have gh; then
    success "gh installed"
  else
    warn "gh unavailable"
  fi
}

#######################################
# Install Oh My Zsh framework if not present
#######################################
install_ohmyzsh() {
  headline "Zsh / Oh My Zsh"
  backup "${HOME}/.oh-my-zsh"
  export RUNZSH=no CHSH=no
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    step "Installing Oh My Zsh"
    if run sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
      success "Oh My Zsh"
    else
      warn "Oh My Zsh failed"
    fi
  else
    note "Oh My Zsh already installed"
  fi
}

#######################################
# Install or update the Pure Zsh prompt
#######################################
install_pure() {
  local dir="${HOME}/.zsh/pure"
  if [[ -d "${dir}/.git" ]]; then
    (
      cd "${dir}" || exit 0
      git pull -q > /dev/null 2>&1 || true
    )
  fi
  if [[ ! -d "${dir}" ]]; then
    headline "Pure Prompt"
    run mkdir -p "${HOME}/.zsh"
    if run git clone --depth 1 https://github.com/sindresorhus/pure.git "${dir}"; then
      success "Pure prompt"
    else
      warn "Pure prompt skipped"
    fi
  else
    note "Pure prompt present"
  fi
}

#######################################
# Install/update selected Zsh plugins under Oh My Zsh custom dir
#######################################
install_zsh_plugins() {
  headline "Zsh Plugins"
  local base="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"
  run mkdir -p "${base}"
  local repos=(
    zsh-autosuggestions=https://github.com/zsh-users/zsh-autosuggestions
    zsh-syntax-highlighting=https://github.com/zsh-users/zsh-syntax-highlighting
    zsh-z=https://github.com/agkozak/zsh-z
    you-should-use=https://github.com/MichaelAquilina/zsh-you-should-use
  )
  local r name url target
  for r in "${repos[@]}"; do
    name="${r%%=*}"
    url="${r#*=}"
    target="${base}/${name}"
    if [[ -d "${target}/.git" ]]; then
      (
        cd "${target}" || exit 0
        git pull -q > /dev/null 2>&1 || true
      )
      note "${name} updated"
      continue
    fi
    step "Plugin ${name}"
    if run git clone --depth 1 "${url}" "${target}"; then
      success "${name}"
    else
      warn "${name} failed"
    fi
  done
}

#######################################
# Install NVM (if missing) and ensure latest LTS Node is installed/active
#######################################
install_nvm_node() {
  headline "Node / NVM"
  if [[ ! -d "${HOME}/.nvm" ]]; then
    step "Installing NVM ${NVM_VERSION}"
    run bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
  else
    note "NVM already present"
  fi
  export NVM_DIR="${HOME}/.nvm"
  load_nvm
  if have nvm; then
    # Helper with retry (network resilience)
    nvm_install_lts() {
      local attempt=1 max=3 rc=0
      while ((attempt <= max)); do
        step "Installing/Updating Node LTS (attempt ${attempt}/${max})"
        if run nvm install --lts; then
          return 0
        fi
        rc=$?
        warn "Node LTS install attempt ${attempt} failed (rc=${rc})"
        sleep 2
        ((attempt++))
      done
      return "${rc}"
    }
    # Determine versions.
    set +u
    local current_node remote_lts
    current_node="$(node --version 2> /dev/null | sed 's/^v//')"
    remote_lts="$(nvm version-remote --lts 2> /dev/null | sed 's/^v//')"
    set -u

    if [[ -z "${current_node}" ]]; then
      if nvm_install_lts; then
        run nvm use --lts > /dev/null || true
        success "Node $(node --version 2> /dev/null || echo '?')"
      else
        warn "Failed to install Node LTS after retries"
      fi
    else
      if [[ -n "${remote_lts}" && "${current_node}" == "${remote_lts}" ]]; then
        note "Node LTS v${current_node} already active"
      else
        if [[ -n "${remote_lts}" ]]; then
          if nvm_install_lts; then
            run nvm use --lts > /dev/null || true
            success "Node updated to $(node --version 2> /dev/null || echo '?')"
          else
            warn "Node LTS update failed after retries (current: ${current_node:-none})"
          fi
        else
          if nvm_install_lts; then
            run nvm use --lts > /dev/null || true
            success "Node $(node --version 2> /dev/null || echo '?')"
          else
            warn "Node LTS install failed (remote LTS unresolved)"
          fi
        fi
      fi
    fi
  else
    warn "nvm not available"
  fi
}

#######################################
# Install JS helper tools (ni, pnpm, diff-so-fancy) via npm global
#######################################
install_js_tooling() {
  headline "JS Tooling (ni / pnpm / diff-so-fancy)"
  have node || {
    warn "Node missing—skip JS tooling"
    return
  }
  if ! have ni; then
    step "Install ni"
    if run npm install -g @antfu/ni; then
      success "ni"
    else
      warn "ni failed"
    fi
  else
    note "ni present"
  fi
  if ! have pnpm; then
    step "Install pnpm"
    if run npm install -g pnpm@latest; then
      success "pnpm"
    else
      warn "pnpm failed"
    fi
  else
    note "pnpm present"
  fi
  if ! have diff-so-fancy; then
    step "Install diff-so-fancy"
    if run npm install -g diff-so-fancy; then
      success "diff-so-fancy"
    else
      warn "diff-so-fancy failed"
    fi
  else
    note "diff-so-fancy present"
  fi
}

#######################################
# Ensure ~/.local/bin is present on PATH in ~/.zshrc
# Globals:
#   HOME
#   PATH
# Returns:
#   0 always
#######################################
ensure_local_bin_path() {
  # shellcheck disable=SC2016
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) return 0 ;;
  esac
  # shellcheck disable=SC2016
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.zshrc"
  note "Added ~/.local/bin to PATH"
}

#######################################
# Create a symlink if the destination is absent
# Globals:
#   DRY_RUN
# Arguments:
#   $1 - source path
#   $2 - destination path
# Returns:
#   0 on success, non-zero on failure
#######################################
ensure_symlink() {
  local src="$1" dest="$2"
  run mkdir -p "$(dirname "${dest}")"
  if [[ -e "${dest}" ]]; then
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) ln -s ${src} ${dest}"
    return 0
  fi
  if ln -s "${src}" "${dest}"; then
    return 0
  fi
  return 1
}

#######################################
# Handle Debian-specific fd symlink when binary is named fdfind
# Globals:
#   HOME
#   PATH
# Returns:
#   0 always
#######################################
debian_fd_symlink() {
  if have fd || ! have fdfind; then
    return 0
  fi
  step "Creating fd symlink for fdfind"
  if ensure_symlink "$(command -v fdfind)" "${HOME}/.local/bin/fd"; then
    ensure_local_bin_path
    if have fd; then
      success "fd available"
    else
      warn "fd symlink not yet in PATH for current session"
    fi
  else
    warn "Failed to create fd symlink"
  fi
}

#######################################
# Handle Debian-specific bat symlink when binary is named batcat
# Globals:
#   HOME
#   PATH
# Returns:
#   0 always
#######################################
debian_bat_symlink() {
  if have bat || ! have batcat; then
    return 0
  fi
  step "Creating bat symlink for batcat"
  if ensure_symlink "/usr/bin/batcat" "${HOME}/.local/bin/bat"; then
    ensure_local_bin_path
    if have bat; then
      success "bat available"
    else
      echo 'alias bat=batcat' >> "${HOME}/.zshrc"
      warn "bat symlink not yet in PATH for current session; alias added"
    fi
  else
    warn "Failed to create bat symlink"
  fi
}

#######################################
# Install fzf/fd/bat/tree packages per platform
# Globals:
#   OS_TYPE
# Returns:
#   0 always
#######################################
install_dev_util_packages() {
  case "${OS_TYPE}" in
    debian)
      ensure_pkgs "fzf stack" fzf fd-find bat tree
      debian_fd_symlink
      debian_bat_symlink
      ;;
    redhat) ensure_pkgs "fzf stack" fzf bat tree fd-find ;;
    arch) ensure_pkgs "fzf stack" fzf bat tree fd ;;
    macos) ensure_pkgs "fzf stack" fzf bat tree fd ;;
    *) warn "Skip fzf stack (manual)" ;;
  esac
}

#######################################
# Configure Charm repo and install glow on Debian
# Returns:
#   0 on success, non-zero on failure
#######################################
install_glow_debian() {
  step "Prepare glow (Charm repo)"
  if [[ ! -f /etc/apt/keyrings/charm.gpg ]]; then
    run sudo mkdir -p /etc/apt/keyrings
    if run bash -c 'curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg'; then
      success "Charm GPG key added"
    else
      warn "Failed to add Charm GPG key"
    fi
  fi
  if [[ ! -f /etc/apt/sources.list.d/charm.list ]]; then
    if run bash -c 'echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null'; then
      success "Charm apt repo added"
    else
      warn "Failed to write Charm repo list"
    fi
  fi
  if ! run sudo apt-get update -y; then
    warn "apt update failed for glow repo"
  fi
  if pkg_install glow; then
    success "glow installed"
    return 0
  fi
  warn "glow install failed via repo; attempting fallback binary"
  install_glow_debian_fallback
}

#######################################
# Fallback glow installation for Debian using binary tarball
# Globals:
#   HOME
# Returns:
#   0 on success, non-zero on failure
#######################################
install_glow_debian_fallback() {
  local glow_version="1.5.1"
  local arch glow_arch="" tmpd tar url
  arch="$(uname -m)"
  case "${arch}" in
    x86_64 | amd64) glow_arch=amd64 ;;
    aarch64 | arm64) glow_arch=arm64 ;;
    *)
      warn "Unsupported arch for glow fallback (${arch})"
      return 1
      ;;
  esac
  tmpd="$(mktemp -d)" || true
  if [[ -z "${tmpd}" ]]; then
    warn "Failed to create temp dir for glow fallback"
    return 1
  fi
  tar="glow_${glow_version}_linux_${glow_arch}.tar.gz"
  url="https://github.com/charmbracelet/glow/releases/download/v${glow_version}/${tar}"
  step "Downloading glow fallback ${glow_version}"
  if run curl -fsSL "${url}" -o "${tmpd}/${tar}" && run tar -xzf "${tmpd}/${tar}" -C "${tmpd}" glow; then
    if [[ -w /usr/local/bin ]]; then
      run install -m 0755 "${tmpd}/glow" /usr/local/bin/glow || true
    else
      run mkdir -p "${HOME}/.local/bin"
      run install -m 0755 "${tmpd}/glow" "${HOME}/.local/bin/glow" || true
      ensure_local_bin_path
    fi
    if have glow; then
      success "glow (fallback)"
      return 0
    fi
    warn "glow fallback present but not in PATH"
    return 1
  fi
  warn "glow fallback download failed"
  return 1
}

#######################################
# Install glow when not already available
#######################################
install_glow_if_missing() {
  if have glow; then
    return 0
  fi
  case "${OS_TYPE}" in
    debian) install_glow_debian ;;
    arch) pkg_install glow ;;
    macos) pkg_install glow ;;
    redhat) pkg_install glow || warn "glow skipped" ;;
    *) warn "Install glow manually" ;;
  esac
}

#######################################
# Ensure hub alias exists when gh is present
#######################################
alias_hub_to_gh() {
  if have hub || ! have gh; then
    return 0
  fi
  if ! grep -q "alias hub=" "${HOME}/.zshrc" 2> /dev/null; then
    echo "alias hub='gh'" >> "${HOME}/.zshrc"
  fi
}

#######################################
# Install pyenv and ensure latest Python is active
# Globals:
#   HOME
#   PATH (modified)
# Returns:
#   0 always
#######################################
ensure_pyenv_ready() {
  if [[ ! -d "${HOME}/.pyenv" ]]; then
    step "Install pyenv"
    if ! run bash -c 'curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash'; then
      warn "pyenv installer failed"
      return
    fi
  else
    note "pyenv present"
  fi
  export PYENV_ROOT="${HOME}/.pyenv"
  export PATH="${PYENV_ROOT}/bin:${PATH}"
  if have pyenv; then
    eval "$(pyenv init - 2> /dev/null)" || true
    ensure_latest_pyenv_python
  fi
}

#######################################
# Install latest Python via pyenv with fallback to existing versions
# Returns:
#   0 always
#######################################
ensure_latest_pyenv_python() {
  local existing latest highest_installed
  existing="$(pyenv versions --bare 2> /dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' || true)"
  latest="$(pyenv install --list 2> /dev/null | grep -E '^[ ]*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')"
  if [[ -z "${latest}" ]]; then
    warn "Could not determine latest Python 3.x release"
    return
  fi
  if printf '%s\n' "${existing}" | grep -qx "${latest}"; then
    note "Latest Python ${latest} already installed (selecting)"
    run pyenv global "${latest}" || true
    success "Python ${latest} active"
    return
  fi
  step "Installing latest Python ${latest} (pyenv)"
  install_python_build_deps
  if run pyenv install -s "${latest}" && run pyenv global "${latest}"; then
    success "Python ${latest} active"
    return
  fi
  warn "Failed to build Python ${latest}"
  if [[ -n "${existing}" ]]; then
    highest_installed="$(printf '%s\n' "${existing}" | sort -V | tail -1)"
    if [[ -n "${highest_installed}" ]]; then
      run pyenv global "${highest_installed}" || true
      note "Using existing pyenv Python ${highest_installed}"
    fi
  else
    warn "No pyenv Python available; system Python remains"
  fi
}

#######################################
# Install assorted developer utilities (fzf, fd, bat, glow, pyenv, etc.)
#######################################
install_dev_extras() {
  headline "Dev Utilities (fzf fd bat tree glow pyenv hub alias)"
  install_dev_util_packages
  install_glow_if_missing
  alias_hub_to_gh
  ensure_pyenv_ready
}

#######################################
# Apply or symlink .zshrc and help file depending on local vs remote install
#######################################
apply_dotfiles() {
  headline "Dotfiles (.zshrc + help)"
  if remote_install; then
    step "Fetch remote .zshrc"
    download .zshrc "${HOME}/.zshrc.tmp" || die ".zshrc download failed"
    backup "${HOME}/.zshrc"
    mv "${HOME}/.zshrc.tmp" "${HOME}/.zshrc"
    success ".zshrc applied"
    step "Fetch remote help"
    if download .zshrc.help.md "${HOME}/.zshrc.help.md.tmp"; then
      if mv "${HOME}/.zshrc.help.md.tmp" "${HOME}/.zshrc.help.md"; then
        success "help applied"
      else
        warn "failed to apply help file"
      fi
    else
      warn "help file missing"
    fi
  else
    if [[ -f "${SCRIPT_DIR}/.zshrc" ]]; then
      backup "${HOME}/.zshrc"
      ln -sf "${SCRIPT_DIR}/.zshrc" "${HOME}/.zshrc"
      success "symlink .zshrc"
    else
      warn "Local .zshrc not found; attempting remote fetch"
      if download .zshrc "${HOME}/.zshrc.tmp" && mv "${HOME}/.zshrc.tmp" "${HOME}/.zshrc"; then
        success "Downloaded remote .zshrc"
      else
        warn "Remote .zshrc unavailable; generating minimal fallback"
        backup "${HOME}/.zshrc"
        cat > "${HOME}/.zshrc" << 'EOF'
# Minimal fallback .zshrc (auto-generated)
export PATH="$HOME/bin:$PATH"
export EDITOR="nvim"
# pyenv
if [ -d "$HOME/.pyenv" ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - 2>/dev/null)" || true
fi
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
# Pure prompt (if cloned)
fpath=("$HOME/.zsh/pure" $fpath)
autoload -U promptinit; promptinit 2>/dev/null || true
prompt pure 2>/dev/null || true
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF
        success "Created fallback .zshrc"
      fi
    fi
    if [[ -f "${SCRIPT_DIR}/.zshrc.help.md" ]]; then
      backup "${HOME}/.zshrc.help.md"
      ln -sf "${SCRIPT_DIR}/.zshrc.help.md" "${HOME}/.zshrc.help.md"
      success "symlink help"
    fi
  fi
}

#######################################
# Switch login shell to zsh if not already
#######################################
set_default_shell() {
  headline "Default Shell"
  if [[ ${SHELL:-} == *zsh ]]; then
    note "Already zsh"
    return 0
  fi
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  if [[ -z "${zsh_path}" ]]; then
    warn "zsh not found"
    return 0
  fi
  step "Setting default shell to zsh"
  if run chsh -s "${zsh_path}" "${USER}"; then
    success "Shell changed"
  else
    warn "chsh failed (manual: chsh -s ${zsh_path})"
  fi
}

#######################################
# Print a summary of installed tools and next steps
#######################################
summary() {
  headline "Summary"
  printf "%bInstalled targets%b\n" "${C_BOLD}" "${C_RESET}"
  local c
  for c in zsh git curl wget gh nvm node ni pnpm fzf fd bat tree diff-so-fancy pyenv glow; do
    if have "${c}"; then
      printf "  %b✔%b %s\n" "${C_GREEN}" "${C_RESET}" "${c}"
    else
      printf "  %b✖%b %s\n" "${C_RED}" "${C_RESET}" "${c}"
    fi
  done
  [[ -d "${BACKUP_DIR}" ]] && note "Backups in ${BACKUP_DIR}"
  printf "\nNext: restart shell or run: %bexec zsh%b\n" "${C_CYAN}" "${C_RESET}"
  if remote_install; then
    printf "Re-run later: curl -fsSL %s/install.sh | bash\n" "${DOTFILES_RAW}"
  fi
  info "Log: ${LOG_FILE}"
}

#######################################
# Perform a lightweight validation of key artifacts
#######################################
self_test() {
  headline "Self-Test"
  local failed=0 binary
  for binary in zsh git curl; do
    if ! have "${binary}"; then
      failed=1
      warn "${binary} missing"
    fi
  done
  if [[ ! -f "${HOME}/.zshrc" ]]; then
    failed=1
    warn ".zshrc missing"
  fi
  if [[ ${failed} -eq 0 ]]; then
    success "Basic self-test passed"
  else
    warn "Self-test encountered issues"
  fi
}

#######################################
# Orchestrate full installation sequence
#######################################
main() {
  headline "Initialize"
  require_internet
  install_base
  install_gh_cli
  install_ohmyzsh
  install_pure
  install_zsh_plugins
  install_nvm_node
  install_js_tooling
  install_dev_extras
  apply_dotfiles
  set_default_shell
  self_test
  summary
  success "Installation complete"
}

main "$@"
