#!/bin/bash
# Zsh, Oh My Zsh, Pure prompt, plugins, and dotfile application.
set -Eeuo pipefail

#######################################
# install_ohmyzsh
# Installs Oh My Zsh non-interactively if not already present.
#######################################
install_ohmyzsh() {
  export RUNZSH=no CHSH=no
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    step "Installing Oh My Zsh"
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
      success "Oh My Zsh"
    else
      warn "Oh My Zsh failed"
    fi
  else
    note "Oh My Zsh already installed"
  fi
}

#######################################
# install_pure_prompt
# Installs or updates the Pure prompt theme under ~/.zsh/pure.
#######################################
install_pure_prompt() {
  local dir="${HOME}/.zsh/pure"
  if [[ -d "${dir}/.git" ]]; then
    (
      cd "${dir}" || exit 0
      git pull -q > /dev/null 2>&1 || true
    )
  fi
  if [[ ! -d "${dir}" ]]; then
    step "Pure Prompt"
    mkdir -p "${HOME}/.zsh"
    if git clone --depth 1 https://github.com/sindresorhus/pure.git "${dir}"; then
      success "Pure prompt"
    else
      warn "Pure prompt skipped"
    fi
  else
    note "Pure prompt present"
  fi
}

#######################################
# install_zsh_plugins
# Clones or updates a curated list of Oh My Zsh compatible plugins.
#######################################
install_zsh_plugins() {
  local base="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"
  mkdir -p "${base}"
  local -a repos=(
    "zsh-autosuggestions=https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting=https://github.com/zsh-users/zsh-syntax-highlighting"
    "zsh-z=https://github.com/agkozak/zsh-z"
    "you-should-use=https://github.com/MichaelAquilina/zsh-you-should-use"
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
    if git clone --depth 1 "${url}" "${target}"; then
      success "${name}"
    else
      warn "${name} failed"
    fi
  done
}

#######################################
# apply_dotfiles
# Symlinks or fetches remote .zshrc into $HOME depending on arguments.
# Arguments: script_dir remote_url(optional)
#######################################
apply_dotfiles() {
  local script_dir="$1"
  local remote="${2:-}"
  if [[ -n "${remote}" ]]; then
    step "Fetch remote .zshrc"
    if curl -fsSL "${remote}/.zshrc" -o "${HOME}/.zshrc.tmp"; then
      if mv "${HOME}/.zshrc.tmp" "${HOME}/.zshrc"; then
        success ".zshrc applied"
      else
        warn "Failed to move downloaded .zshrc"
      fi
    else
      warn ".zshrc fetch failed"
    fi
  else
    if [[ -f "${script_dir}/.zshrc" ]]; then
      ln -sf "${script_dir}/.zshrc" "${HOME}/.zshrc"
      success "symlink .zshrc"
    else
      warn "Local .zshrc not found"
    fi
  fi
}

#######################################
# set_default_shell_zsh
# Changes the user's default login shell to zsh if not already.
#######################################
set_default_shell_zsh() {
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
  if chsh -s "${zsh_path}" "${USER}"; then
    success "Shell changed"
  else
    warn "chsh failed (manual: chsh -s ${zsh_path})"
  fi
}
