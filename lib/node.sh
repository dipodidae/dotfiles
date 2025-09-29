#!/bin/bash
# Node / NVM / JS tooling helpers.
set -Eeuo pipefail

#######################################
# load_nvm
# Loads nvm environment (if NVM_DIR set and scripts present) enabling nvm commands.
# Globals: NVM_DIR
# Outputs: none
#######################################
load_nvm() {
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
# nvm_install_lts_retry
# Attempt to install latest LTS Node with simple retry loop (3 attempts).
# Returns: 0 on success; last non-zero from nvm install on failure.
#######################################
nvm_install_lts_retry() {
  local -i attempt=1 max=3 rc=0
  while ((attempt <= max)); do
    if nvm install --lts; then
      return 0
    fi
    rc="$?"
    sleep 2
    ((attempt++))
  done
  return "${rc}"
}

#######################################
# ensure_node_lts
# Ensures an LTS Node version is installed & active via nvm (installs nvm dir if needed).
# Globals: HOME NVM_DIR
#######################################
ensure_node_lts() {
  export NVM_DIR="${HOME}/.nvm"
  load_nvm
  if ! command -v nvm > /dev/null 2>&1; then
    warn "nvm not available"
    return 0
  fi
  set +u
  local current_node remote_lts
  current_node="$(node --version 2> /dev/null | sed 's/^v//')"
  remote_lts="$(nvm version-remote --lts 2> /dev/null | sed 's/^v//')"
  set -u
  if [[ -z "${current_node}" ]]; then
    if nvm_install_lts_retry; then
      nvm use --lts > /dev/null || true
      success "Node $(node --version 2> /dev/null || echo '?')"
    else
      warn "Failed to install Node LTS"
    fi
    return 0
  fi
  if [[ -n "${remote_lts}" && "${current_node}" == "${remote_lts}" ]]; then
    note "Node LTS v${current_node} already active"
    return 0
  fi
  if nvm_install_lts_retry; then
    nvm use --lts > /dev/null || true
    success "Node updated to $(node --version 2> /dev/null || echo '?')"
  else
    warn "Node LTS update failed (current: ${current_node:-none})"
  fi
}

#######################################
# install_js_global_tools
# Installs a curated set of global JS CLI tools (ni, pnpm, diff-so-fancy) if missing.
#######################################
install_js_global_tools() {
  if ! command -v node > /dev/null 2>&1; then
    warn "Node missing—skip JS tooling"
    return
  fi
  if ! command -v ni > /dev/null 2>&1; then
    step "Install ni"
    if npm install -g @antfu/ni; then
      success "ni"
    else
      warn "ni install failed"
    fi
  else
    note "ni present"
  fi
  if ! command -v pnpm > /dev/null 2>&1; then
    step "Install pnpm"
    if npm install -g pnpm@latest; then
      success "pnpm"
    else
      warn "pnpm install failed"
    fi
  else
    note "pnpm present"
  fi
  if ! command -v diff-so-fancy > /dev/null 2>&1; then
    step "Install diff-so-fancy"
    if npm install -g diff-so-fancy; then
      success "diff-so-fancy"
    else
      warn "diff-so-fancy install failed"
    fi
  else
    note "diff-so-fancy present"
  fi
}
