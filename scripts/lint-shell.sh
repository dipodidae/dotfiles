#!/bin/bash
# Canonical shell linting pipeline - matches GitHub Actions exactly.
# This is the ONE source of truth for all linting: local dev, pre-commit, CI.
set -Eeuo pipefail

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

#######################################
# Print error message to stderr.
# Arguments:
#   * - message text
# Outputs:
#   Writes to stderr
#######################################
err() { echo "[ERR] $*" >&2; }

#######################################
# Print info message to stdout.
# Arguments:
#   * - message text
# Outputs:
#   Writes to stdout
#######################################
log() { echo "[INF] $*"; }

#######################################
# Run shellcheck on bash shell scripts.
# Matches GitHub Actions "Check shell scripts (bash)" step.
# Globals:
#   REPO_ROOT
# Returns:
#   0 on success, non-zero on lint failures.
#######################################
check_bash() {
  log "==> Shellcheck (bash) ..."
  shellcheck --color=auto --shell=bash \
    "${REPO_ROOT}"/install.sh \
    "${REPO_ROOT}"/lib/*.sh \
    "${REPO_ROOT}"/scripts/*.sh
}

#######################################
# Run shellcheck on zsh scripts (advisory).
# Matches GitHub Actions "Check shell scripts (zsh)" step.
# Globals:
#   REPO_ROOT
# Returns:
#   Always 0 (advisory only).
#######################################
check_zsh() {
  log "==> Shellcheck (zsh - advisory) ..."
  if [[ -d "${REPO_ROOT}/.zsh" ]]; then
    shellcheck --color=auto --shell=bash --severity=warning \
      "${REPO_ROOT}"/.zsh/*.zsh 2>&1 || true
  fi
  if [[ -f "${REPO_ROOT}/.zshrc" ]]; then
    shellcheck --color=auto --shell=bash --severity=warning \
      "${REPO_ROOT}/.zshrc" 2>&1 || true
  fi
}

#######################################
# Check formatting with shfmt.
# Matches GitHub Actions "Check formatting (shfmt)" step.
# Globals:
#   REPO_ROOT
# Returns:
#   0 if formatted, non-zero if changes needed.
#######################################
check_format() {
  log "==> Check formatting (shfmt -i 2 -ci -sr) ..."
  if ! shfmt -i 2 -ci -sr -d \
    "${REPO_ROOT}"/install.sh \
    "${REPO_ROOT}"/lib/*.sh \
    "${REPO_ROOT}"/scripts/*.sh; then
    err "Formatting issues detected. Run: shfmt -i 2 -ci -sr -w ."
    return 1
  fi
}

#######################################
# Run style audit heuristics.
# Matches GitHub Actions "Style audit" step.
# Globals:
#   SCRIPT_DIR
# Returns:
#   0 on success, non-zero on audit failures.
#######################################
check_audit() {
  log "==> Style audit (Google Shell Style Guide heuristics) ..."
  "${SCRIPT_DIR}/audit-shell-style.sh"
}

#######################################
# Main function to run comprehensive shell linting
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes lint results to stdout/stderr
# Returns:
#   0 if all checks pass, 1 if issues found
#######################################
main() {
  local exit_code=0

  # Run all checks (continue on failure to show all issues)
  check_bash || exit_code=1
  check_zsh # Advisory only, never fails
  check_format || exit_code=1
  check_audit || exit_code=1

  if ((exit_code == 0)); then
    log "✓ All lint checks passed."
  else
    err "✗ Lint checks failed."
  fi

  return "${exit_code}"
}

main "$@"
