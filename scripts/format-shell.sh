#!/bin/bash
# Canonical shell formatting script.
# Formats all shell files with the ONE authoritative style (matches GitHub Actions).
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

#######################################
# Format fish scripts with fish_indent.
# Globals:
#   REPO_ROOT
# Arguments:
#   1 - 1 to check only, 0 to write
# Returns:
#   0 on success (or if no changes needed in check mode), 1 otherwise.
#######################################
format_fish() {
  local check_only="$1"

  local -a targets
  mapfile -t targets < <(git ls-files '*.fish' 2> /dev/null || true)
  if ((${#targets[@]} == 0)); then
    return 0
  fi
  if ! command -v fish_indent > /dev/null; then
    echo "fish_indent not available; skipping fish files"
    return 0
  fi

  if ((check_only)); then
    if ! fish_indent --check "${targets[@]}" > /dev/null 2>&1; then
      echo "✗ Fish files need formatting. Run: fish_indent -w <file>" >&2
      return 1
    fi
    return 0
  fi

  fish_indent -w "${targets[@]}"
}

#######################################
# Format all shell files with shfmt.
# Uses the ONE canonical style: -i 2 -ci -sr
# Globals:
#   REPO_ROOT
# Arguments:
#   --check: Check only, don't write (exit 1 if changes needed)
# Returns:
#   0 on success (or if no changes needed in check mode)
# Outputs:
#   Writes formatting status to stdout/stderr.
#######################################
main() {
  local check_only=0
  if [[ "${1:-}" == "--check" ]]; then
    check_only=1
  fi

  cd "${REPO_ROOT}"

  local -a shfmt_args=(-i 2 -ci -sr)

  if ((check_only)); then
    echo "Checking formatting..."
    shfmt_args+=(-d)
  else
    echo "Formatting shell files..."
    shfmt_args+=(-w)
  fi

  local -a targets
  mapfile -t targets < <(git ls-files '*.sh' '*.bash' 2> /dev/null || true)

  if ((${#targets[@]} == 0)); then
    echo "No shell files found"
    return 0
  fi

  local exit_code=0

  if ! shfmt "${shfmt_args[@]}" "${targets[@]}"; then
    if ((check_only)); then
      echo "✗ Files need formatting. Run: ./scripts/format-shell.sh" >&2
      exit_code=1
    fi
  fi

  format_fish "${check_only}" || exit_code=1

  if ((exit_code == 0)); then
    echo "✓ All files properly formatted."
  fi
  return "${exit_code}"
}

main "$@"
