#!/bin/bash
# Fish shell configuration management.
# Fish is a supported secondary shell: zsh stays the login shell, but fish
# gets the same environment (Node/NVM on PATH, pnpm, ni) and macros.
# shellcheck shell=bash

#######################################
# fish::config_dir
# Print the fish configuration directory, honoring XDG_CONFIG_HOME.
# Globals:
#   XDG_CONFIG_HOME
#   HOME
# Outputs:
#   Writes the directory path to stdout.
#######################################
fish::config_dir() {
  printf '%s\n' "${XDG_CONFIG_HOME:-${HOME}/.config}/fish"
}

#######################################
# fish::apply_config
# Symlink the repo's fish/config.fish into the fish config directory,
# backing up any existing file first.
# Globals:
#   SCRIPT_DIR
# Outputs:
#   Success/warn messages.
# Returns:
#   0 on success, 1 if the source is missing or the symlink fails.
#######################################
fish::apply_config() {
  local src="${SCRIPT_DIR}/fish/config.fish"
  local dest
  dest="$(fish::config_dir)/config.fish"

  if [[ ! -f "${src}" ]]; then
    warn "Local fish/config.fish not found"
    return 1
  fi

  fs::ensure_dir "$(dirname "${dest}")"
  fs::backup "${dest}"

  if fs::ensure_symlink "${src}" "${dest}"; then
    success "symlink fish config"
    return 0
  fi

  error "Symlink creation failed for fish config"
  warn "Failed to establish fish config symlink"
  return 1
}

#######################################
# fish::verify_node_path
# Confirm fish can resolve the npm globals the installer provides.
# Advisory only — never fails the install.
# Outputs:
#   Success or warn message per missing tool.
# Returns:
#   0 always.
#######################################
fish::verify_node_path() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) skipping fish PATH verification"
    return 0
  fi

  local -a missing=()
  local tool
  for tool in node pnpm ni; do
    if ! fish -l -c "command -q ${tool}" > /dev/null 2>&1; then
      missing+=("${tool}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    warn "fish cannot resolve: ${missing[*]}"
    return 0
  fi
  success "fish resolves node, pnpm and ni"
}

#######################################
# fish::setup
# Main orchestrator for fish configuration.
# Skips cleanly when fish is not installed.
# Outputs:
#   Headline and delegated messages.
# Returns:
#   0 always.
#######################################
fish::setup() {
  headline "Fish"

  if ! core::have fish; then
    note "fish not installed — skipping"
    return 0
  fi

  fish::apply_config || warn "fish config symlink failed"
  fish::verify_node_path
}
