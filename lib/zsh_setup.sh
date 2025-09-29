#!/usr/bin/env bash
# Zsh, Oh My Zsh, Pure prompt, plugins, and dotfile application.
set -Eeuo pipefail

install_ohmyzsh() {
  export RUNZSH=no CHSH=no
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
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

install_pure_prompt() {
  local dir="$HOME/.zsh/pure"
  if [[ -d "$dir/.git" ]]; then (cd "$dir" && git pull -q >/dev/null 2>&1 || true); fi
  if [[ ! -d "$dir" ]]; then
    step "Pure Prompt"; mkdir -p "$HOME/.zsh"
    if git clone --depth 1 https://github.com/sindresorhus/pure.git "$dir"; then success "Pure prompt"; else warn "Pure prompt skipped"; fi
  else note "Pure prompt present"; fi
}

install_zsh_plugins() {
  local base="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"; mkdir -p "$base"
  local repos=(
    zsh-autosuggestions=https://github.com/zsh-users/zsh-autosuggestions
    zsh-syntax-highlighting=https://github.com/zsh-users/zsh-syntax-highlighting
    zsh-z=https://github.com/agkozak/zsh-z
    you-should-use=https://github.com/MichaelAquilina/zsh-you-should-use
  )
  local r name url target
  for r in "${repos[@]}"; do
    name="${r%%=*}"; url="${r#*=}"; target="$base/$name"
    if [[ -d "$target/.git" ]]; then
      (cd "$target" && git pull -q >/dev/null 2>&1 || true)
      note "$name updated"; continue
    fi
    step "Plugin $name"
    if git clone --depth 1 "$url" "$target"; then success "$name"; else warn "$name failed"; fi
  done
}

apply_dotfiles() {
  local script_dir="$1" remote="$2"
  if [[ -n "$remote" ]]; then
    step "Fetch remote .zshrc"; curl -fsSL "$remote/.zshrc" -o "$HOME/.zshrc.tmp" && mv "$HOME/.zshrc.tmp" "$HOME/.zshrc" && success ".zshrc applied" || warn ".zshrc fetch failed"
  else
    if [[ -f "$script_dir/.zshrc" ]]; then
      ln -sf "$script_dir/.zshrc" "$HOME/.zshrc"; success "symlink .zshrc"
    else
      warn "Local .zshrc not found"
    fi
  fi
}

set_default_shell_zsh() {
  [[ ${SHELL:-} == *zsh ]] && { note "Already zsh"; return 0; }
  local zsh_path; zsh_path="$(command -v zsh || true)"; [[ -n "$zsh_path" ]] || { warn "zsh not found"; return 0; }
  step "Setting default shell to zsh"
  if chsh -s "$zsh_path" "$USER"; then success "Shell changed"; else warn "chsh failed (manual: chsh -s $zsh_path)"; fi
}
