#!/bin/bash
# Node / NVM / JS tooling helpers.
# shellcheck shell=bash

#######################################
# node::load_nvm
# Source NVM if available.
# Globals:
#   NVM_DIR
# Returns:
#   0 always
#######################################
node::load_nvm() {
  if [[ -z "${NVM_DIR:-}" ]]; then
    return 0
  fi
  node::_clean_npmrc
  if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    set +u
    # shellcheck disable=SC1091
    . "${NVM_DIR}/nvm.sh"
    set -u
  fi
}

#######################################
# Remove globalconfig and prefix from user .npmrc.
# These settings are incompatible with NVM.
# Globals:
#   HOME
# Outputs:
#   Warn message if entries were removed.
#######################################
node::_clean_npmrc() {
  local npmrc="${HOME}/.npmrc"
  if [[ ! -f "${npmrc}" ]]; then
    return 0
  fi
  if grep -qE '^\s*(globalconfig|prefix)\s*=' "${npmrc}"; then
    warn "Removing globalconfig/prefix from .npmrc (incompatible with nvm)"
    sed -i.bak '/^\s*\(globalconfig\|prefix\)\s*=/d' "${npmrc}"
  fi
}

#######################################
# node::ensure_nvm_installed
# Install NVM if not present, then load it.
# Globals:
#   DOTFILES_NVM_VERSION
#   NVM_DIR (exported)
# Outputs:
#   Step/success/warn messages
#######################################
node::ensure_nvm_installed() {
  export NVM_DIR="${HOME}/.nvm"
  if [[ -d "${NVM_DIR}" ]]; then
    note "NVM already present"
  else
    step "Installing NVM ${DOTFILES_NVM_VERSION}"
    # PROFILE=/dev/null prevents NVM's installer from appending loader
    # lines to ~/.bashrc; we source NVM from ~/.zshrc instead.
    if ! core::run bash -c \
      "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${DOTFILES_NVM_VERSION}/install.sh | PROFILE=/dev/null bash"; then
      warn "NVM install script failed"
    fi
  fi
  node::load_nvm
  if ! core::have nvm; then
    warn "nvm not available"
  fi
}

#######################################
# node::_nvm_cmd
# Execute an nvm subcommand in the current shell with nounset disabled.
# Must run in the current shell (not a subshell) so that PATH changes
# from "nvm install/use" are visible to subsequent commands.
# Arguments:
#   NVM subcommand and args
# Returns:
#   Exit status of nvm command
#######################################
node::_nvm_cmd() {
  set +u
  nvm "$@"
  local rc=$?
  set -u
  return $rc
}

#######################################
# node::_nvm_use_lts
# Activate Node LTS version without noisy output.
# Must run in the current shell so the updated PATH persists.
# Returns:
#   Exit status of nvm use
#######################################
node::_nvm_use_lts() {
  set +u
  nvm use --lts > /dev/null
  local rc=$?
  set -u
  return $rc
}

#######################################
# node::install_lts_retry
# Install Node LTS with retry logic.
# Returns:
#   0 on success, 1 on failure after retries
#######################################
node::install_lts_retry() {
  step "Installing/Updating Node LTS"
  if ! core::retry_cmd 3 node::_nvm_cmd install --lts; then
    warn "Node LTS install failed after retries"
    return 1
  fi
  return 0
}

#######################################
# node::get_current_version
# Get current Node version (without 'v' prefix).
# Outputs: version string or empty
#######################################
node::get_current_version() {
  if ! core::have node; then
    printf '%s\n' ""
    return 0
  fi

  local version=""
  version="$(node --version 2> /dev/null || true)"
  version="${version#v}"
  printf '%s\n' "${version}"
}

#######################################
# node::get_lts_version
# Get remote LTS version (without 'v' prefix).
# Outputs: version string or empty
#######################################
node::get_lts_version() {
  local version=""
  version="$(core::without_nounset nvm version-remote --lts 2> /dev/null || true)"
  printf '%s\n' "${version#v}"
}

#######################################
# node::ensure_lts_active
# Ensure Node LTS is installed and active.
# Outputs:
#   Step/success/warn messages
# Returns:
#   0 always
#######################################
node::ensure_lts_active() {
  if ! core::have nvm; then
    warn "nvm not available"
    return 0
  fi
  local current remote
  current="$(node::get_current_version)"
  remote="$(node::get_lts_version)"

  if [[ -z "${current}" ]]; then
    if node::install_lts_retry; then
      core::run node::_nvm_use_lts || true
      success "Node $(node::get_current_version)"
    else
      warn "Node LTS install failed"
    fi
    return 0
  fi

  if [[ -n "${remote}" && "${current}" == "${remote}" ]]; then
    note "Node LTS v${current} already active"
    return 0
  fi

  if node::install_lts_retry; then
    core::run node::_nvm_use_lts || true
    success "Node updated to $(node::get_current_version)"
  else
    warn "Node LTS update failed (current: ${current:-none})"
  fi
}

#######################################
# node::ensure_npm_global
# Install npm global package if not present.
# Arguments:
#   1 - npm package spec (e.g., "@antfu/ni", "pnpm@latest")
#######################################
node::ensure_npm_global() {
  local pkg="$1"
  local tool="${pkg##*/}"
  tool="${tool%%@*}"
  if core::have "${tool}"; then
    note "${tool} present"
    return 0
  fi
  step "Install ${tool}"
  if core::run npm install -g "${pkg}"; then
    success "${tool}"
  else
    warn "${tool} install failed"
    return 1
  fi
}

#######################################
# node::install_global_tools
# Install essential npm global packages.
# Outputs:
#   Step/success/warn messages
#######################################
node::install_global_tools() {
  if ! core::have node; then
    warn "Node missing—skip JS tooling"
    return
  fi
  node::ensure_npm_global "@antfu/ni" || true
  node::ensure_npm_global "pnpm@latest" || true
  node::ensure_npm_global "diff-so-fancy" || true
}

#######################################
# node::setup
# Main orchestrator for Node/NVM/tooling setup.
# Outputs:
#   Headline and delegated messages
#######################################
node::setup() {
  headline "Node / JavaScript"
  node::ensure_nvm_installed
  node::ensure_lts_active
  node::install_global_tools
}
