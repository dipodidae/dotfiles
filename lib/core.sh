#!/bin/bash
# Core helpers shared across installer modules.
# shellcheck shell=bash

#######################################
# core::run
# Execute a command while honoring dry-run mode.
# Globals:
#   DRY_RUN
# Arguments:
#   Command and args to execute
# Returns:
#   Exit status of command or 0 in dry-run mode
#######################################
core::run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) $*"
    return 0
  fi
  "$@"
}

#######################################
# core::sudo
# sudo wrapper that respects dry-run logging.
#######################################
core::sudo() {
  core::run sudo "$@"
}

#######################################
# core::have
# Check if a command exists in PATH.
#######################################
core::have() {
  command -v "$1" > /dev/null 2>&1
}

#######################################
# core::detect_os
# Detect host OS family (debian, redhat, arch, macos, other).
#######################################
core::detect_os() {
  if [[ "${OSTYPE}" == linux-* ]]; then
    if core::have apt; then
      echo debian
    elif core::have dnf || core::have yum; then
      echo redhat
    elif core::have pacman; then
      echo arch
    else
      echo linux
    fi
  elif [[ "${OSTYPE}" == darwin* ]]; then
    echo macos
  else
    echo unknown
  fi
}

#######################################
# core::require_internet
# Simple connectivity check against GitHub.
#######################################
core::require_internet() {
  step "Checking internet"
  if ! core::run curl -fsSL https://github.com > /dev/null; then
    die "No internet connectivity"
  fi
  success "Network OK"
}

#######################################
# core::is_remote_install
# Returns 0 when installer is running from remote (no .git directory).
# Globals:
#   SCRIPT_DIR
#######################################
core::is_remote_install() {
  [[ ! -d "${SCRIPT_DIR}/.git" ]]
}

#######################################
# core::download
# Download file from repository raw path with retry support.
# Globals:
#   DOTFILES_RAW, DRY_RUN
#######################################
core::download() {
  local relative_path="$1" dest="$2"
  local src="${DOTFILES_RAW}/${relative_path}"
  core::retry_cmd 3 curl -fsSL "${src}" -o "${dest}"
}

#######################################
# core::retry_cmd
# Retry a command with exponential backoff.
# Arguments:
#   1 - max attempts
#   2+ - command and args
# Returns:
#   0 on success, last exit code on failure
#######################################
core::retry_cmd() {
  local -i max_attempts="$1"
  shift
  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) retry: $*"
    return 0
  fi
  local -i attempt=1 sleep_time=1
  while ((attempt <= max_attempts)); do
    if "$@"; then
      return 0
    fi
    if ((attempt < max_attempts)); then
      sleep "${sleep_time}"
      ((sleep_time *= 2))
    fi
    ((attempt++))
  done
  return 1
}

#######################################
# core::git_clone_or_update
# Clone repo if missing, or pull if already present.
# Arguments:
#   1 - repo URL
#   2 - destination path
# Returns:
#   0 on success
#######################################
core::git_clone_or_update() {
  local url="$1" dest="$2"
  if [[ -d "${dest}/.git" ]]; then
    (
      cd "${dest}" || return 0
      core::run git pull -q > /dev/null 2>&1 || true
    )
    return 0
  fi
  core::run git clone --depth 1 "${url}" "${dest}"
}
