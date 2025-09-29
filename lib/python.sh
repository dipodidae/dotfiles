#!/bin/bash
# Python / pyenv related helpers.
set -Eeuo pipefail

#######################################
# install_python_build_deps
# Installs OS-specific build prerequisites for compiling Python via pyenv.
# Globals: OS_TYPE
#######################################
install_python_build_deps() {
  case "${OS_TYPE}" in
    debian)
      ensure_pkgs "python build deps" build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils \
        tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
      ;;
    redhat)
      if command -v dnf > /dev/null 2>&1; then
        pkg_install gcc gcc-c++ make openssl-devel bzip2 bzip2-devel \
          libffi-devel zlib-devel readline-devel sqlite sqlite-devel \
          xz xz-devel tk tk-devel || true
      else
        pkg_install gcc gcc-c++ make openssl-devel bzip2 bzip2-devel \
          libffi-devel zlib-devel readline-devel sqlite sqlite-devel \
          xz xz-devel tk tk-devel || true
      fi
      ;;
    arch)
      ensure_pkgs "python build deps" base-devel openssl zlib xz tk || true
      ;;
    macos)
      if ! xcode-select -p > /dev/null 2>&1; then
        step "Installing Xcode Command Line Tools"
        xcode-select --install || true
      fi
      ;;
    *)
      warn "Skipping automatic Python build deps for ${OS_TYPE}"
      ;;
  esac
}

#######################################
# ensure_latest_python
# Installs/updates pyenv and ensures the latest stable Python is installed & set global.
# Falls back to highest installed version if build fails.
#######################################
ensure_latest_python() {
  if [[ ! -d "${HOME}/.pyenv" ]]; then
    step "Install pyenv"
    if ! curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash; then
      warn "pyenv installer failed"
    fi
  else
    note "pyenv present"
  fi
  export PYENV_ROOT="${HOME}/.pyenv"
  export PATH="${PYENV_ROOT}/bin:${PATH}"
  if command -v pyenv > /dev/null 2>&1; then
    eval "$(pyenv init - 2> /dev/null)" || true
    local existing latest highest_installed
    existing="$(pyenv versions --bare 2> /dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' || true)"
    latest="$(pyenv install --list 2> /dev/null | grep -E '^[ ]*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')"
    if [[ -z "${latest}" ]]; then
      warn "Could not determine latest Python"
      return 0
    fi
    if printf '%s\n' "${existing}" | grep -qx "${latest}"; then
      note "Latest Python ${latest} already installed"
      pyenv global "${latest}" || true
      success "Python ${latest} active"
      return 0
    fi
    step "Installing Python ${latest} (pyenv)"
    install_python_build_deps
    if pyenv install -s "${latest}" && pyenv global "${latest}"; then
      success "Python ${latest} active"
    else
      warn "Failed to build Python ${latest}"
      if [[ -n "${existing}" ]]; then
        highest_installed="$(printf '%s\n' "${existing}" | sort -V | tail -1)"
        if [[ -n "${highest_installed}" ]]; then
          pyenv global "${highest_installed}"
          note "Using existing ${highest_installed}"
        fi
      fi
    fi
  fi
}
