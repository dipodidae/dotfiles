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
  local -a scripts
  mapfile -t scripts < <(git -C "${REPO_ROOT}" ls-files '*.sh' '*.bash' 2> /dev/null || true)

  if ((${#scripts[@]} == 0)); then
    log "No bash scripts found"
    return 0
  fi

  local -a abs_scripts
  for script in "${scripts[@]}"; do
    abs_scripts+=("${REPO_ROOT}/${script}")
  done

  shellcheck --color=auto --shell=bash "${abs_scripts[@]}"
}

#######################################
# Run syntax validation on zsh scripts (advisory).
# Uses "zsh -n" because shellcheck cannot parse modern zsh syntax.
# Matches GitHub Actions "Check shell scripts (zsh)" step.
# Globals:
#   REPO_ROOT
# Returns:
#   0 when all zsh files parse, 1 if syntax errors were found.
#######################################
check_zsh() {
  log "==> Zsh syntax check ..."

  local -a zfiles
  mapfile -t zfiles < <(git -C "${REPO_ROOT}" ls-files '*.zsh' 2> /dev/null || true)
  if [[ -f "${REPO_ROOT}/.zshrc" ]]; then
    zfiles+=(".zshrc")
  fi

  if ((${#zfiles[@]} == 0)); then
    log "No zsh files found"
    return 0
  fi

  if ! command -v zsh > /dev/null; then
    log "zsh binary not available; skipping syntax check"
    return 0
  fi

  local -a abs_zfiles
  for file in "${zfiles[@]}"; do
    abs_zfiles+=("${REPO_ROOT}/${file}")
  done

  local -a failed
  local status=0
  local candidate
  local tmp_zdotdir
  tmp_zdotdir="$(mktemp -d)"
  for candidate in "${abs_zfiles[@]}"; do
    if ! ZDOTDIR="${tmp_zdotdir}" zsh --no-rcs --no-globalrcs -n -- "${candidate}" > /dev/null 2>&1; then
      failed+=("${candidate}")
      status=1
    fi
  done
  rm -rf "${tmp_zdotdir}"

  if ((status != 0)); then
    err "Zsh syntax errors detected in:"
    printf '  %s\n' "${failed[@]}" >&2
    return 1
  fi

  log "Zsh syntax looks good"
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

  local -a format_targets
  mapfile -t format_targets < <(git -C "${REPO_ROOT}" ls-files 'install.sh' 'lib/*.sh' 'scripts/*.sh' 2> /dev/null || true)

  if ((${#format_targets[@]} == 0)); then
    log "No shell files found for formatting"
    return 0
  fi

  local -a abs_format_targets
  for file in "${format_targets[@]}"; do
    abs_format_targets+=("${REPO_ROOT}/${file}")
  done

  if ! shfmt -i 2 -ci -sr -d "${abs_format_targets[@]}"; then
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
  check_zsh || exit_code=1
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
