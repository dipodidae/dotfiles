#!/bin/bash
# Developer tooling installers (fzf, glow, gh, etc.).
# shellcheck shell=bash

dev_tools::ensure_local_bin_path() {
  # shellcheck disable=SC2016
  if fs::append_once "${HOME}/.zshrc" 'export PATH="$HOME/.local/bin:$PATH"'; then
    note "Added ${HOME}/.local/bin to PATH"
  else
    note "${HOME}/.local/bin already in PATH"
  fi
}

dev_tools::ensure_debian_fd_symlink() {
  if core::have fd || ! core::have fdfind; then
    return 0
  fi
  step "Creating fd symlink for fdfind"
  if fs::ensure_symlink "$(command -v fdfind)" "${HOME}/.local/bin/fd"; then
    dev_tools::ensure_local_bin_path
    if core::have fd; then
      success "fd available"
    else
      warn "fd symlink not yet in PATH for current session"
    fi
  else
    warn "Failed to create fd symlink"
  fi
}

dev_tools::ensure_debian_bat_symlink() {
  if core::have bat || ! core::have batcat; then
    return 0
  fi
  step "Creating bat symlink for batcat"
  if fs::ensure_symlink "/usr/bin/batcat" "${HOME}/.local/bin/bat"; then
    dev_tools::ensure_local_bin_path
    if core::have bat; then
      success "bat available"
    else
      fs::append_once "${HOME}/.zshrc" 'alias bat=batcat'
      warn "bat symlink not yet in PATH for current session; alias added"
    fi
  else
    warn "Failed to create bat symlink"
  fi
}

dev_tools::ensure_fzf_stack() {
  case "${OS_TYPE}" in
    debian)
      pkg::ensure_group "fzf stack" fzf fd-find bat tree
      dev_tools::ensure_debian_fd_symlink
      dev_tools::ensure_debian_bat_symlink
      ;;
    redhat)
      pkg::ensure_group "fzf stack" fzf bat tree fd-find
      ;;
    arch)
      pkg::ensure_group "fzf stack" fzf bat tree fd
      ;;
    macos)
      pkg::ensure_group "fzf stack" fzf bat tree fd
      ;;
    *)
      warn "Skip fzf stack (manual)"
      ;;
  esac
}

dev_tools::install_glow_fallback() {
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
  if core::run curl -fsSL "${url}" -o "${tmpd}/${tar}" && core::run tar -xzf "${tmpd}/${tar}" -C "${tmpd}" glow; then
    if [[ -w /usr/local/bin ]]; then
      core::run install -m 0755 "${tmpd}/glow" /usr/local/bin/glow || true
    else
      fs::ensure_dir "${HOME}/.local/bin"
      core::run install -m 0755 "${tmpd}/glow" "${HOME}/.local/bin/glow" || true
      dev_tools::ensure_local_bin_path
    fi
    if core::have glow; then
      success "glow (fallback)"
      return 0
    fi
    warn "glow fallback present but not in PATH"
    return 1
  fi
  warn "glow fallback download failed"
  return 1
}

dev_tools::ensure_glow() {
  if core::have glow; then
    return 0
  fi
  case "${OS_TYPE}" in
    debian)
      pkg::ensure_apt_repo "charm" \
        "https://repo.charm.sh/apt/gpg.key" \
        "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *"
      if pkg::install glow; then
        success "glow installed"
      else
        warn "glow install failed via repo; attempting fallback"
        dev_tools::install_glow_fallback || warn "glow unavailable"
      fi
      ;;
    arch | macos)
      pkg::install glow
      ;;
    redhat)
      pkg::install glow || warn "glow skipped"
      ;;
    *)
      warn "Install glow manually"
      ;;
  esac
}

dev_tools::ensure_hub_alias() {
  if core::have hub || ! core::have gh; then
    return 0
  fi
  fs::append_once "${HOME}/.zshrc" "alias hub='gh'"
}

dev_tools::ensure_gh_cli() {
  headline "GitHub CLI"
  if core::have gh; then
    note "gh already present ($(gh --version | head -n1))"
    return 0
  fi
  case "${OS_TYPE}" in
    debian)
      pkg::ensure_apt_repo "github-cli" \
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
      if pkg::install gh; then
        success "gh installed"
      fi
      ;;
    redhat)
      pkg::install gh || warn "Install gh manually: https://cli.github.com"
      ;;
    arch)
      pkg::install github-cli
      ;;
    macos)
      pkg::install gh
      ;;
    *)
      warn "Install gh manually"
      ;;
  esac
  if core::have gh; then
    success "gh ready"
  else
    warn "gh unavailable"
  fi
}

dev_tools::setup() {
  headline "Developer Utilities"
  dev_tools::ensure_gh_cli
  dev_tools::ensure_fzf_stack
  dev_tools::ensure_glow
  dev_tools::ensure_hub_alias
}
