#!/bin/bash
# Python / pyenv related helpers.
# shellcheck shell=bash

python::install_build_deps() {
  if [[ "${SKIP_PACKAGES}" == "1" ]]; then
    note "Skipping Python build deps (--skip-packages)"
    return 0
  fi
  case "${OS_TYPE}" in
    debian)
      pkg::ensure_group "python build deps" \
        build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev \
        libxmlsec1-dev libffi-dev liblzma-dev
      ;;
    redhat)
      if core::have dnf; then
        pkg::install gcc gcc-c++ make openssl-devel bzip2 bzip2-devel \
          libffi-devel zlib-devel readline-devel sqlite sqlite-devel xz \
          xz-devel tk tk-devel || true
      else
        pkg::install gcc gcc-c++ make openssl-devel bzip2 bzip2-devel \
          libffi-devel zlib-devel readline-devel sqlite sqlite-devel xz \
          xz-devel tk tk-devel || true
      fi
      ;;
    arch)
      pkg::ensure_group "python build deps" base-devel openssl zlib xz tk || true
      ;;
    macos)
      if ! xcode-select -p > /dev/null 2>&1; then
        step "Installing Xcode Command Line Tools"
        core::run xcode-select --install || true
      fi
      ;;
    *)
      warn "Skipping automatic Python build deps for ${OS_TYPE}"
      ;;
  esac
}

python::ensure_pyenv() {
  if [[ ! -d "${HOME}/.pyenv" ]]; then
    step "Install pyenv"
    if ! core::run bash -c 'curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash'; then
      warn "pyenv installer failed"
    fi
  else
    note "pyenv present"
  fi
  export PYENV_ROOT="${HOME}/.pyenv"
  export PATH="${PYENV_ROOT}/bin:${PATH}"
  if core::have pyenv; then
    eval "$(pyenv init - 2> /dev/null)" || true
  fi
}

python::ensure_latest() {
  if ! core::have pyenv; then
    warn "pyenv unavailable"
    return 0
  fi
  local existing latest highest_installed
  existing="$(pyenv versions --bare 2> /dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' || true)"
  latest="$(pyenv install --list 2> /dev/null | grep -E '^[ ]*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')"
  if [[ -z "${latest}" ]]; then
    warn "Could not determine latest Python"
    return 0
  fi
  if printf '%s\n' "${existing}" | grep -qx "${latest}"; then
    note "Latest Python ${latest} already installed"
    core::run pyenv global "${latest}" || true
    success "Python ${latest} active"
    return 0
  fi
  step "Installing Python ${latest} (pyenv)"
  python::install_build_deps
  if core::run pyenv install -s "${latest}" && core::run pyenv global "${latest}"; then
    success "Python ${latest} active"
  else
    warn "Failed to build Python ${latest}"
    if [[ -n "${existing}" ]]; then
      highest_installed="$(printf '%s\n' "${existing}" | sort -V | tail -1)"
      if [[ -n "${highest_installed}" ]]; then
        core::run pyenv global "${highest_installed}" || true
        note "Using existing ${highest_installed}"
      fi
    fi
  fi
}

python::setup() {
  headline "Python / pyenv"
  python::ensure_pyenv
  python::ensure_latest
}
