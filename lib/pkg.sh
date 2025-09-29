#!/usr/bin/env bash
# Package management abstraction.
set -Eeuo pipefail

#######################################
# apt_update_once
# Runs apt-get update once per process (guards with _APT_UPDATED flag) on Debian.
# Globals: _APT_UPDATED
#######################################
apt_update_once() { if [[ "${_APT_UPDATED:-0}" == 0 ]]; then
  sudo apt-get update -y
  _APT_UPDATED=1
fi; }

#######################################
# pkg_install
# Cross-distro package install abstraction; chooses package manager by $OS_TYPE.
# Arguments: package names
# Globals: OS_TYPE
#######################################
pkg_install() { # pkg_install list...
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  case "$OS_TYPE" in
    debian)
      apt_update_once
      sudo apt-get install -y "${pkgs[@]}"
      ;;
    redhat)
      if command -v dnf > /dev/null 2>&1; then sudo dnf install -y "${pkgs[@]}"; else sudo yum install -y "${pkgs[@]}"; fi
      ;;
    arch)
      sudo pacman -S --noconfirm --needed "${pkgs[@]}"
      ;;
    macos)
      command -v brew > /dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null
      brew install "${pkgs[@]}"
      ;;
    *) return 0 ;;
  esac
}

#######################################
# ensure_pkgs
# Idempotently installs a labeled group of packages, logging success/failure.
# Arguments: label pkgs...
#######################################
ensure_pkgs() { # ensure_pkgs label pkgs...
  local label="$1"
  shift
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  step "Installing $label (${pkgs[*]})"
  if pkg_install "${pkgs[@]}"; then
    success "$label ready"
  else
    warn "$label partial/failed"
  fi
}
