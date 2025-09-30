#!/bin/bash
# Node / NVM / JS tooling helpers.
# shellcheck shell=bash

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

node::install_lts_retry() {
  step "Installing/Updating Node LTS"
  if ! core::retry_cmd 3 nvm install --lts; then
    warn "Node LTS install failed after retries"
    return 1
  fi
  return 0
}

node::ensure_lts_active() {
  if ! core::have nvm; then
    warn "nvm not available"
    return 0
  fi
  set +u
  local current_node remote_lts
  current_node="$(node --version 2> /dev/null | sed 's/^v//')"
  remote_lts="$(nvm version-remote --lts 2> /dev/null | sed 's/^v//')"
  set -u
  if [[ -z "${current_node}" ]]; then
    if node::install_lts_retry; then
      core::run nvm use --lts > /dev/null || true
      success "Node $(node --version 2> /dev/null || echo '?')"
    else
      warn "Failed to install Node LTS after retries"
    fi
    return 0
  fi
  if [[ -n "${remote_lts}" && "${current_node}" == "${remote_lts}" ]]; then
    note "Node LTS v${current_node} already active"
    return 0
  fi
  if node::install_lts_retry; then
    core::run nvm use --lts > /dev/null || true
    success "Node updated to $(node --version 2> /dev/null || echo '?')"
  else
    warn "Node LTS update failed (current: ${current_node:-none})"
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

node::install_global_tools() {
  if ! core::have node; then
    warn "Node missing—skip JS tooling"
    return
  fi
  node::ensure_npm_global "@antfu/ni"
  node::ensure_npm_global "pnpm@latest"
  node::ensure_npm_global "diff-so-fancy"
}

node::setup() {
  headline "Node / JavaScript"
  node::ensure_nvm_installed
  node::ensure_lts_active
  node::install_global_tools
}
