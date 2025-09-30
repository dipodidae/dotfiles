#!/bin/bash
# Zsh, Oh My Zsh, Pure prompt, plugins, and dotfile management.
# shellcheck shell=bash

#######################################
# zsh::install_oh_my_zsh
# Install Oh My Zsh framework if not present.
# Globals:
#   RUNZSH (exported)
#   CHSH (exported)
# Outputs:
#   Step/success/warn/note messages
#######################################
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

#######################################
# zsh::install_pure_prompt
# Clone or update Pure prompt theme.
# Outputs:
#   Step/success/warn/note messages
#######################################
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

#######################################
# zsh::install_plugin
# Clone or update a single zsh plugin.
# Arguments:
#   1 - plugin name
#   2 - repository URL
#   3 - base directory path
# Outputs:
#   Step/success/warn/note messages
#######################################
zsh::install_plugin() {
  local name="$1" url="$2" base="$3"
  local target="${base}/${name}"

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
}

#######################################
# zsh::install_plugins
# Clone or update all configured zsh plugins.
# Outputs:
#   Delegated plugin install messages
#######################################
zsh::install_plugins() {
  local base="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"
  fs::ensure_dir "${base}"

  local -a repos=(
    "zsh-autosuggestions=https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting=https://github.com/zsh-users/zsh-syntax-highlighting"
    "zsh-z=https://github.com/agkozak/zsh-z"
    "you-should-use=https://github.com/MichaelAquilina/zsh-you-should-use"
  )

  local entry name url
  for entry in "${repos[@]}"; do
    name="${entry%%=*}"
    url="${entry#*=}"
    zsh::install_plugin "$name" "$url" "$base"
  done
}

#######################################
# zsh::apply_file
# Apply a dotfile via download or symlink.
# Arguments:
#   1 - display name
#   2 - source path
#   3 - destination path
#   4 - mode (download or symlink)
# Outputs:
#   Success/warn messages
#######################################
zsh::apply_file() {
  local name="$1" src="$2" dest="$3" mode="$4"

  fs::backup "$dest"

  if [[ "$mode" == "download" ]]; then
    if core::download "$src" "${dest}.tmp" && mv "${dest}.tmp" "$dest"; then
      success "$name applied"
    else
      warn "Failed to apply $name"
    fi
  elif [[ "$mode" == "symlink" ]]; then
    if fs::ensure_symlink "$src" "$dest"; then
      success "symlink $name"
    else
      warn "Failed to symlink $name"
    fi
  fi
}

#######################################
# zsh::apply_dotfiles
# Apply .zshrc and help file (remote or local).
# Globals:
#   SCRIPT_DIR
# Outputs:
#   Headline and delegated apply messages
#######################################
zsh::apply_dotfiles() {
  headline "Dotfiles (.zshrc + help)"

  if core::is_remote_install; then
    step "Fetch remote .zshrc"
    zsh::apply_file ".zshrc" ".zshrc" "${HOME}/.zshrc" download

    step "Fetch remote help"
    zsh::apply_file "help" ".zshrc.help.md" "${HOME}/.zshrc.help.md" download
    return
  fi

  if [[ -f "${SCRIPT_DIR}/.zshrc" ]]; then
    zsh::apply_file ".zshrc" "${SCRIPT_DIR}/.zshrc" "${HOME}/.zshrc" symlink
  else
    warn "Local .zshrc not found"
  fi

  if [[ -f "${SCRIPT_DIR}/.zshrc.help.md" ]]; then
    zsh::apply_file "help" "${SCRIPT_DIR}/.zshrc.help.md" "${HOME}/.zshrc.help.md" symlink
  fi
}

#######################################
# zsh::ensure_default_shell
# Change default shell to zsh if not already set.
# Globals:
#   SHELL
#   USER
# Outputs:
#   Step/success/warn/note messages
# Returns:
#   0 always
#######################################
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

#######################################
# zsh::setup
# Main orchestrator for zsh/Oh My Zsh/plugins setup.
# Outputs:
#   Headline and delegated messages
#######################################
zsh::setup() {
  headline "Zsh"
  zsh::install_oh_my_zsh
  zsh::install_pure_prompt
  zsh::install_plugins
}
