#!/bin/bash
# Auto-fix shell formatting (shfmt) and show what would be fixed for ShellCheck-suggested easy autofixes (none applied automatically).
set -euo pipefail
shopt -s nullglob globstar

#######################################
# Main function to auto-fix shell formatting
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes formatting results to stdout/stderr
# Returns:
#   0 on success, non-zero on error
#######################################
main() {
  readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "${ROOT_DIR}"

  local -a SH_FILES
  mapfile -t SH_FILES < <(git ls-files '*.sh') || true
  if [[ -f .zshrc ]]; then
    SH_FILES+=(".zshrc")
  fi
  while IFS= read -r -d '' f; do
    SH_FILES+=("${f}")
  done < <(find .zsh -type f -name '*.zsh' -print0 2> /dev/null || true)

  if [[ ${#SH_FILES[@]} -eq 0 ]]; then
    echo "No shell files detected"
    return 0
  fi

  echo "== shfmt (in-place) =="
  if command -v shfmt > /dev/null 2>&1; then
    shfmt -w -i 2 -ci -sr "${SH_FILES[@]}"
  else
    echo "shfmt not installed. Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest" >&2
  fi

  echo "== ShellCheck (advice only) =="
  if command -v shellcheck > /dev/null 2>&1; then
    local f
    for f in "${SH_FILES[@]}"; do
      echo "-- ${f}"
      shellcheck "${f}" || true
    done
  else
    echo "ShellCheck not installed." >&2
  fi

  echo "== Heuristic audit (advisory) =="
  if bash "$(dirname "${BASH_SOURCE[0]}")/audit-shell-style.sh"; then
    echo "Heuristic audit passed."
  else
    echo "(Advisory) heuristic audit reported issues" >&2
  fi

  echo "Done. Review changes with: git diff"
}

main "$@"
