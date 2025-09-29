#!/usr/bin/env bash
# Heuristic audit for non-automated Google Shell Style Guide items.
# Checks:
#  1. Functions lacking header doc blocks (####################################### style) in .sh files.
#  2. Scripts > 120 lines missing a main() definition + final main invocation.
#  3. Warn on files > 400 lines (suggest rewrite consideration).

set -euo pipefail
shopt -s nullglob

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

files=( $(git ls-files '*.sh') )
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .sh scripts found"; exit 0
fi

missing_headers=()
missing_main=()
oversized=()

for f in "${files[@]}"; do
  total_lines=$(wc -l <"$f" | awk '{print $1}')
  # Collect function names (simple regex: start of line, name(), no leading space)
  mapfile -t funs < <(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{' "$f" | sed -E 's/^([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\).*/\1/')
  for fn in "${funs[@]}"; do
    # Skip main – it's documented by existence & call
    [[ $fn == main ]] && continue
    # Look 6 lines above definition for header delimiter
    if ! grep -B6 -E "^${fn}\\s*\\(\\)" "$f" | grep -q '#######################################'; then
      missing_headers+=("$f:$fn")
    fi
  done
  if (( total_lines > 120 )); then
    if grep -q '^main\s*()' "$f"; then
      # Require a tail call to main (allow args)
      if ! tail -n 5 "$f" | grep -Eq '^main(\s+"\$@"|\s+\$@|\s*)$'; then
        missing_main+=("$f:missing tail main call")
      fi
    else
      missing_main+=("$f:no main() defined (script length ${total_lines})")
    fi
  fi
  if (( total_lines > 400 )); then
    oversized+=("$f:${total_lines}")
  fi
done

status=0
if ((${#missing_headers[@]})); then
  echo "Functions missing header comments:" >&2
  printf '  %s\n' "${missing_headers[@]}" >&2
  status=1
fi
if ((${#missing_main[@]})); then
  echo "Scripts needing main() pattern:" >&2
  printf '  %s\n' "${missing_main[@]}" >&2
  status=1
fi
if ((${#oversized[@]})); then
  echo "Oversized scripts (consider refactor):" >&2
  printf '  %s\n' "${oversized[@]}" >&2
fi

if (( status == 0 )); then
  echo "Heuristic style audit passed."; else echo "Heuristic style audit flagged issues." >&2; fi
exit $status
