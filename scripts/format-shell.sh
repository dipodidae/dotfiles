#!/bin/bash
# Canonical shell formatting script.
# Formats all shell files with the ONE authoritative style (matches GitHub Actions).
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

#######################################
# Format all shell files with shfmt.
# Uses the ONE canonical style: -i 2 -ci -sr
# Globals:
#   REPO_ROOT
# Arguments:
#   --check: Check only, don't write (exit 1 if changes needed)
# Returns:
#   0 on success (or if no changes needed in check mode)
#######################################
main() {
  local check_only=0
  if [[ "${1:-}" == "--check" ]]; then
    check_only=1
  fi

  local -a shfmt_args=(-i 2 -ci -sr)

  if ((check_only)); then
    echo "Checking formatting..."
    shfmt_args+=(-d)
  else
    echo "Formatting shell files..."
    shfmt_args+=(-w)
  fi

  if shfmt "${shfmt_args[@]}" \
    "${REPO_ROOT}"/install.sh \
    "${REPO_ROOT}"/lib/*.sh \
    "${REPO_ROOT}"/scripts/*.sh; then
    echo "✓ All files properly formatted."
  else
    if ((check_only)); then
      echo "✗ Files need formatting. Run: ./scripts/format-shell.sh" >&2
      return 1
    fi
  fi
}

main "$@"
