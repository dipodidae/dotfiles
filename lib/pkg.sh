#!/bin/bash
# Package management utilities.
# shellcheck shell=bash

declare -g _PKG_APT_UPDATED=0

#######################################
# pkg::apt_update_once
# Run apt-get update once per session.
# Globals:
#   _PKG_APT_UPDATED (modified)
# Returns:
#   0 always
#######################################
pkg::apt_update_once() {
  if [[ "${_PKG_APT_UPDATED}" == "1" ]]; then
    return 0
  fi
  core::sudo apt-get update -y
  _PKG_APT_UPDATED=1
}

#######################################
# pkg::ensure_homebrew
# Install Homebrew if not present (macOS).
# Returns:
#   0 on success or if already installed
#######################################
pkg::ensure_homebrew() {
  if core::have brew; then
    return 0
  fi
  step "Installing Homebrew"
  core::run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null
}

#######################################
# pkg::install
# Install packages via the OS package manager.
# Globals:
#   OS_TYPE
# Arguments:
#   1+ - package names
# Returns:
#   0 on success, 1 if unsupported OS
#######################################
pkg::install() {
  local -a pkgs=("$@")
  [[ ${#pkgs[@]} -gt 0 ]] || return 0
  case "${OS_TYPE}" in
    debian)
      pkg::apt_update_once
      core::sudo apt-get install -y "${pkgs[@]}"
      ;;
    redhat)
      if core::have dnf; then
        core::sudo dnf install -y "${pkgs[@]}"
      else
        core::sudo yum install -y "${pkgs[@]}"
      fi
      ;;
    arch)
      core::sudo pacman -S --noconfirm --needed "${pkgs[@]}"
      ;;
    macos)
      pkg::ensure_homebrew
      core::run brew install "${pkgs[@]}"
      ;;
    *)
      warn "Package install unsupported for ${OS_TYPE}"
      return 1
      ;;
  esac
}

#######################################
# pkg::ensure_group
# Install a labeled group of packages with user feedback.
# Arguments:
#   1 - label for the group
#   2+ - package names
# Outputs:
#   Step and success/warn messages
#######################################
pkg::ensure_group() {
  local label="$1"
  shift
  local -a pkgs=("$@")
  [[ ${#pkgs[@]} -gt 0 ]] || return 0
  step "Installing ${label} (${pkgs[*]})"
  if pkg::install "${pkgs[@]}"; then
    success "${label} ready"
  else
    warn "${label} failed"
  fi
}

#######################################
# pkg::ensure_apt_repo
# Add a third-party APT repository with GPG key.
# Arguments:
#   1 - repository name
#   2 - GPG key URL
#   3 - repository line
# Outputs:
#   None
# Returns:
#   0 always
#######################################
pkg::ensure_apt_repo() {
  local name="$1" key_url="$2" repo_line="$3"
  core::sudo mkdir -p /etc/apt/keyrings
  if [[ ! -f "/etc/apt/keyrings/${name}.gpg" ]]; then
    core::run bash -c "curl -fsSL '${key_url}' | sudo gpg --dearmor -o /etc/apt/keyrings/${name}.gpg"
  fi
  if [[ ! -f "/etc/apt/sources.list.d/${name}.list" ]]; then
    core::run bash -c "echo '${repo_line}' | sudo tee /etc/apt/sources.list.d/${name}.list >/dev/null"
  fi
  pkg::apt_update_once
}
