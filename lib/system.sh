#!/bin/bash
# System-level orchestration helpers.
# shellcheck shell=bash

system::install_base() {
  if [[ "${SKIP_PACKAGES}" == "1" ]]; then
    info "Skipping base packages"
    return 0
  fi
  headline "Base Packages"
  case "${OS_TYPE}" in
    debian)
      pkg::ensure_group "base" zsh git curl wget ca-certificates gnupg lsb-release
      ;;
    redhat)
      pkg::ensure_group "base" zsh git curl wget ca-certificates gnupg
      ;;
    arch)
      pkg::ensure_group "base" zsh git curl wget
      ;;
    macos)
      pkg::ensure_group "base" zsh git curl wget
      ;;
    *)
      warn "Manual install required: zsh git curl wget"
      ;;
  esac
}

system::self_test() {
  headline "Self-Test"
  local failed=0 binary
  for binary in zsh git curl; do
    if ! core::have "${binary}"; then
      failed=1
      warn "${binary} missing"
    fi
  done
  if [[ ! -f "${HOME}/.zshrc" ]]; then
    failed=1
    warn ".zshrc missing"
  fi
  if [[ ${failed} -eq 0 ]]; then
    success "Basic self-test passed"
  else
    warn "Self-test encountered issues"
  fi
}

system::summary() {
  headline "Summary"
  printf "%bInstalled targets%b\n" "${C_BOLD}" "${C_RESET}"
  local tool
  for tool in zsh git curl wget gh nvm node ni pnpm fzf fd bat tree diff-so-fancy pyenv glow; do
    if core::have "${tool}"; then
      printf "  %b✔%b %s\n" "${C_GREEN}" "${C_RESET}" "${tool}"
    else
      printf "  %b✖%b %s\n" "${C_RED}" "${C_RESET}" "${tool}"
    fi
  done
  if [[ -d "${BACKUP_DIR}" ]]; then
    note "Backups in ${BACKUP_DIR}"
  fi
  printf "\nNext: restart shell or run: %bexec zsh%b\n" "${C_CYAN}" "${C_RESET}"
  if core::is_remote_install; then
    printf "Re-run later: curl -fsSL %s/install.sh | bash\n" "${DOTFILES_RAW}"
  fi
  info "Log: ${LOG_FILE}"
}
