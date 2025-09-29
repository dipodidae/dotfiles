#!/bin/bash
# Aggregate shell lint helper.
# Runs ShellCheck on bash/zsh related files and shfmt in diff-safe (check) mode.
set -euo pipefail
shopt -s nullglob globstar

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
  readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "${ROOT_DIR}"

  # Collect files
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

  echo "== ShellCheck =="
  local FAIL=0
  local f
  for f in "${SH_FILES[@]}"; do
    if shellcheck "${f}"; then
      :
    else
      echo "-- lint issues: ${f}" >&2
      FAIL=1
    fi
  done

  echo "== shfmt (style check only) =="
  if command -v shfmt > /dev/null 2>&1; then
    if ! shfmt -d -i 2 -ci -sr "${SH_FILES[@]}"; then
      echo "Formatting differences found. Run: scripts/fix-shell.sh" >&2
      FAIL=1
    fi
  else
    echo "shfmt not installed (skip). Install via: go install mvdan.cc/sh/v3/cmd/shfmt@latest" >&2
  fi

  echo "== Heuristic audit (headers & main) =="
  if ! bash "$(dirname "${BASH_SOURCE[0]}")/audit-shell-style.sh"; then
    FAIL=1
  fi

  if [[ ${FAIL} -ne 0 ]]; then
    echo "Shell lint failed." >&2
    exit 1
  fi

  echo "All shell lint checks (including heuristic audit) passed."
}

main "$@"
