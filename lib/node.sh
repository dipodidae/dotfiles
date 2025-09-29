#!/usr/bin/env bash
# Node / NVM / JS tooling helpers.
set -Eeuo pipefail

load_nvm() {
  if [[ -z "${NVM_DIR:-}" ]]; then return 0; fi
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    set +u
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    set -u
  fi
}

nvm_install_lts_retry() {
  local attempt=1 max=3 rc=0
  while (( attempt <= max )); do
    if nvm install --lts; then return 0; fi
    rc=$?; sleep 2; ((attempt++))
  done
  return "$rc"
}

ensure_node_lts() {
  export NVM_DIR="$HOME/.nvm"
  load_nvm
  command -v nvm >/dev/null 2>&1 || { warn "nvm not available"; return 0; }
  set +u
  local current_node remote_lts
  current_node="$(node --version 2>/dev/null | sed 's/^v//')"
  remote_lts="$(nvm version-remote --lts 2>/dev/null | sed 's/^v//')"
  set -u
  if [[ -z "$current_node" ]]; then
    if nvm_install_lts_retry; then
      nvm use --lts >/dev/null || true
      success "Node $(node --version 2>/dev/null || echo '?')"
    else
      warn "Failed to install Node LTS"
    fi
    return 0
  fi
  if [[ -n "$remote_lts" && "$current_node" == "$remote_lts" ]]; then
    note "Node LTS v$current_node already active"; return 0
  fi
  if nvm_install_lts_retry; then
    nvm use --lts >/dev/null || true
    success "Node updated to $(node --version 2>/dev/null || echo '?')"
  else
    warn "Node LTS update failed (current: ${current_node:-none})"
  fi
}

install_js_global_tools() {
  command -v node >/dev/null 2>&1 || { warn "Node missing—skip JS tooling"; return; }
  if ! command -v ni >/dev/null 2>&1; then
    step "Install ni"; npm install -g @antfu/ni && success ni || warn ni
  else note "ni present"; fi
  if ! command -v pnpm >/dev/null 2>&1; then
    step "Install pnpm"; npm install -g pnpm@latest && success pnpm || warn pnpm
  else note "pnpm present"; fi
  if ! command -v diff-so-fancy >/dev/null 2>&1; then
    step "Install diff-so-fancy"; npm install -g diff-so-fancy && success diff-so-fancy || warn diff-so-fancy
  else note "diff-so-fancy present"; fi
}
