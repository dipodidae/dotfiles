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
  if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    set +u
    # shellcheck disable=SC1091
    . "${NVM_DIR}/nvm.sh"
    set -u
  fi
}

#######################################
# node::ensure_nvm_installed
# Install NVM if not present, then load it.
# Globals:
#   NVM_VERSION
#   NVM_DIR (exported)
# Outputs:
#   Step/success/warn messages
#######################################
node::ensure_nvm_installed() {
  export NVM_DIR="${HOME}/.nvm"
  if [[ -d "${NVM_DIR}" ]]; then
    note "NVM already present"
  else
    step "Installing NVM ${NVM_VERSION}"
    core::run bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
  fi
  node::load_nvm
  if ! core::have nvm; then
    warn "nvm not available"
  fi
}

#######################################
# node::_nvm_cmd
# Execute an nvm subcommand with nounset disabled.
# Arguments:
#   NVM subcommand and args
# Returns:
#   Exit status of nvm command
#######################################
node::_nvm_cmd() {
  core::without_nounset nvm "$@"
}

#######################################
# node::_nvm_use_lts
# Activate Node LTS version without noisy output.
# Returns:
#   Exit status of nvm use
#######################################
node::_nvm_use_lts() {
  core::without_nounset nvm use --lts > /dev/null
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
  node --version 2> /dev/null | sed 's/^v//'
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
    fi
    success "Node $(node::get_current_version)"
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
  node::ensure_npm_global "@antfu/ni"
  node::ensure_npm_global "pnpm@latest"
  node::ensure_npm_global "diff-so-fancy"
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
