#!/bin/bash
# Zsh, Oh My Zsh, Pure prompt, plugins, and dotfile management.
# shellcheck shell=bash

zsh::install_oh_my_zsh() {
  export RUNZSH=no CHSH=no
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    step "Installing Oh My Zsh"
    if core::run sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
      success "Oh My Zsh"
    else
      warn "Oh My Zsh failed"
    fi
  else
    note "Oh My Zsh already installed"
  fi
}

zsh::install_pure_prompt() {
  local dir="${HOME}/.zsh/pure"
  fs::ensure_dir "${HOME}/.zsh"
  if [[ -d "${dir}" ]]; then
    note "Pure prompt present"
  else
    step "Pure Prompt"
  fi
  if core::git_clone_or_update "https://github.com/sindresorhus/pure.git" "${dir}"; then
    [[ -d "${dir}" ]] && success "Pure prompt"
  else
    warn "Pure prompt skipped"
  fi
}

zsh::install_plugins() {
  local base="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"
  fs::ensure_dir "${base}"
  local -a repos=(
    "zsh-autosuggestions=https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting=https://github.com/zsh-users/zsh-syntax-highlighting"
    "zsh-z=https://github.com/agkozak/zsh-z"
    "you-should-use=https://github.com/MichaelAquilina/zsh-you-should-use"
  )
  local entry name url target
  for entry in "${repos[@]}"; do
    name="${entry%%=*}"
    url="${entry#*=}"
    target="${base}/${name}"
    if [[ -d "${target}" ]]; then
      note "${name} present"
    else
      step "Plugin ${name}"
    fi
    if core::git_clone_or_update "${url}" "${target}"; then
      [[ ! -d "${target}/.git" ]] || success "${name}"
    else
      warn "${name} failed"
    fi
  done
}

zsh::apply_dotfiles() {
  headline "Dotfiles (.zshrc + help)"
  if core::is_remote_install; then
    step "Fetch remote .zshrc"
    if core::download ".zshrc" "${HOME}/.zshrc.tmp"; then
      fs::backup "${HOME}/.zshrc"
      if mv "${HOME}/.zshrc.tmp" "${HOME}/.zshrc"; then
        success ".zshrc applied"
      else
        warn "Failed to apply downloaded .zshrc"
      fi
    else
      warn ".zshrc download failed"
    fi
    step "Fetch remote help"
    if core::download ".zshrc.help.md" "${HOME}/.zshrc.help.md.tmp" && mv "${HOME}/.zshrc.help.md.tmp" "${HOME}/.zshrc.help.md"; then
      success "help applied"
    else
      warn "help file missing"
    fi
    return
  fi
  if [[ -f "${SCRIPT_DIR}/.zshrc" ]]; then
    fs::backup "${HOME}/.zshrc"
    if fs::ensure_symlink "${SCRIPT_DIR}/.zshrc" "${HOME}/.zshrc"; then
      success "symlink .zshrc"
    else
      warn "Failed to symlink .zshrc"
    fi
  else
    warn "Local .zshrc not found"
  fi
  if [[ -f "${SCRIPT_DIR}/.zshrc.help.md" ]]; then
    fs::backup "${HOME}/.zshrc.help.md"
    if fs::ensure_symlink "${SCRIPT_DIR}/.zshrc.help.md" "${HOME}/.zshrc.help.md"; then
      success "symlink help"
    else
      warn "Failed to symlink help"
    fi
  fi
}

zsh::ensure_default_shell() {
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
  if core::run chsh -s "${zsh_path}" "${USER}"; then
    success "Shell changed"
  else
    warn "chsh failed (manual: chsh -s ${zsh_path})"
  fi
}

zsh::setup() {
  headline "Zsh"
  zsh::install_oh_my_zsh
  zsh::install_pure_prompt
  zsh::install_plugins
}
