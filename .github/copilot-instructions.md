# Copilot Instructions: Shell Scripting Standards for this Repo

These instructions guide GitHub Copilot (and reviewers) to generate *consistent, correct, secure* Bash code for this repository.

Source inspiration: Google Shell Style Guide (paraphrased/condensed). Full reference: https://google.github.io/styleguide/shellguide.html. This document extracts only enforcement targets plus project‑specific conventions. Do **not** copy the external guide verbatim into code comments.

---
## 1. Scope & Goals
All executable scripts here are Bash (`#!/bin/bash`). Primary goals:
1. Reliability under `set -Eeuo pipefail` (preferred in top-level scripts).
2. Readability & maintainability for medium/long scripts (≥1 supporting function → require `main`).
3. Safe quoting, explicit error handling, minimal subshell surprises.
4. Consistent formatting (2 spaces, no tabs) – enforced by `shfmt` (see `.shfmt.conf`).

---
## 2. Required File Structure
Order at top of every non-trivial script:
1. Shebang: `#!/bin/bash`
2. (Optional) `set -Eeuo pipefail` (or at least `set -euo pipefail` if `-E` not desired)
3. Top-level comment: brief one‑line description.
4. Constants / exported vars (uppercase, `readonly` and/or `export` immediately).
5. Function definitions (grouped together; no executable statements interleaved).
6. Final function: `main()`.
7. Last line: `main "$@"` (no other execution code after it).

Short utility (< ~30 lines, linear) may omit `main`, but keep description and shebang.

---
## 3. Function Header Template (Use When Non-Obvious, Non-Trivial, or In Libraries)
```
#######################################
# <Verb phrase summary.>
# Globals:
#   VAR1
#   VAR2 (modified)
# Arguments:
#   <name/positional> - <purpose>
# Outputs:
#   <stdout|stderr description or 'None'>
# Returns:
#   0 on success, non-zero on <failure condition>
#######################################
```
Keep sections only if applicable; omit empty ones. For very small obvious helpers you may skip the header but keep a one‑line comment if intent is not crystal clear.

---
## 4. Naming & Variables
DO:
- Functions & local variables: `lower_snake_case`.
- Namespaces (rare): `package::function_name` (avoid if interactive auto-complete confusion is likely).
- Constants / exported: `UPPER_SNAKE_CASE`; declare once, then `readonly` immediately.
- Prefer `local` within functions. If assignment uses command substitution, split declaration & assignment to preserve exit code:
  ```bash
  local result
  result="$(some_cmd)"
  ```
DON'T:
- Use aliases in scripts (define a function instead).
- Leak loop variables (always `local var` inside functions before loops when feasible).

---
## 5. Quoting & Expansion (High Importance)
Rules for Copilot completions:
1. **Always double-quote** variable, command substitution, and parameter expansions unless *intentional* word splitting or globbing is desired (rare; add a comment if omitted on purpose).
2. Use `"$@"` when forwarding all arguments; never bare `$@` or `$*` (except in an informational echo message where concatenation is desired).
3. Prefer `${var}` form for non-special variables; plain `$1`, `$?`, `$#`, etc. are fine.
4. When concatenating with suffix/prefix, use braces: `"${name}_suffix"`.
5. Use arrays to build argument lists safely: `cmd "${args[@]}"`.

---
## 6. Control Flow & Formatting
Formatting enforced by `shfmt` (2 spaces). Copilot must propose code that matches these patterns:
- if/for/while: `if <cond>; then`, `for x in ...; do`, `while <cond>; do` on one line; closing tokens aligned.
- Case blocks:
  ```bash
  case "${flag}" in
    a) do_a ;;  # single simple command OK inline
    long)
      do_long
      more
      ;;
    *) error "Unexpected flag: ${flag}" ;;
  esac
  ```
- Pipelines longer than 1 line: line breaks before `|` segment with backslash and indent the following command by 2 spaces:
  ```bash
  cmd1 \
    | cmd2 \
    | cmd3
  ```
  (Keep it consistent; entire pipeline preceded by any explanatory comment.)

---
## 7. Tests & Conditionals
Prefer `[[ ... ]]` for tests. Patterns / regex inside RHS unquoted when intended.
String tests:
- Emptiness: `[[ -z "${var}" ]]` or `[[ -n "${var}" ]]` (avoid padding hacks like `${var}X`).
Numeric tests:
- Use arithmetic contexts: `if (( value > 3 )); then` or `[[ "${value}" -gt 3 ]]` (first preferred).
Avoid `[ ... ]` unless portability is explicitly required (not the case here).

---
## 8. Error Handling & Logging
Guidelines:
- Centralize error messages to stderr via helper (e.g., `err()` or existing logging helpers in `lib/logging.sh`).
- After critical command: use guard pattern:
  ```bash
  if ! some_command "${arg}"; then
    err "Failed doing X"
    return 1  # or exit 1 in top-level
  fi
  ```
- For pipelines where needed, capture `PIPESTATUS` *immediately* if branching based on individual failures.

---
## 9. Arrays & Argument Construction
Use arrays for assembling flags or file lists:
```bash
declare -a flags
flags=( --color=auto --format=short )
[[ -n "${extra}" ]] && flags+=( --extra "${extra}" )
tool "${flags[@]}"
```
Avoid building a single string then word-splitting.

---
## 10. Arithmetic
Use `$(( ... ))` or `(( ... ))` only. Never `expr`, `let`, or `$[ ... ]`.
Example:
```bash
local -i retries=0
(( retries++ ))
if (( retries >= 5 )); then
  err "Too many retries"
  return 1
fi
```

Be cautious with `set -e` + standalone `(( expression ))` that evaluates to 0.

---
## 11. Command Substitution
Always use `$(...)` (never backticks). Nest freely without escaping.
```bash
value="$(grep pattern "${file}")"
```

---
## 12. Safe Globs & File Ops
When using globs that might match `-*` names or where ambiguity exists, prefer explicit `./*` pattern.
Avoid unguarded `rm -rf *`; use a path prefix.

---
## 13. Avoiding Subshell Pitfalls
Do **not** rely on mutated variables inside `while` loops fed by a pipe. Instead:
```bash
while read -r line; do
  process_line "${line}"
done < <(producer_command)
```
Or use `readarray -t lines < <(producer_command)` then iterate.

---
## 14. Anti-Patterns (Reject / Refactor)
Copilot should NOT emit:
- Backtick command substitutions.
- Unquoted variable expansions with potential spaces/globs.
- `eval` unless absolutely necessary (rare; prefer arrays or associative logic). If unavoidable, include a comment justifying.
- Aliases in scripts.
- Mixing executable statements between function definitions.
- Repeated boilerplate if a helper exists (e.g., repeated curl logic vs a shared function).
- `for x in $(command)` where output can contain spaces (use while/readarray approach instead).
- Bare `cat file | command` UUOC style (use redirection) unless pipeline readability meaningfully improves.

---
## 15. Formatting Automation
Enforced by tools already present:
- `shfmt` (config in `.shfmt.conf`).
- `shellcheck` (config in `.shellcheckrc`).
- Make targets:
  - `make format`
  - `make format-check`
  - `make lint` (shellcheck)
Pre-commit hook: run `./scripts/setup-git-hook.sh` to install format gate.
Copilot solutions should naturally pass these.

---
## 16. Suggested Snippet Patterns
Logging helper pattern:
```bash
err() { echo "[ERR] $(date +'%Y-%m-%dT%H:%M:%S%z') $*" >&2; }
log() { echo "[INF] $*"; }
```
Retry skeleton:
```bash
retry_with_backoff() {
  local -i attempts=0 max_attempts=5 sleep=1
  while (( attempts < max_attempts )); do
    if "$@"; then return 0; fi
    (( attempts++ ))
    sleep "$sleep"
    (( sleep = sleep * 2 ))
  done
  return 1
}
```
Argument forwarding:
```bash
main() {
  local -a args
  args=( "$@" )
  # process args
}
main "$@"
```

---
## 17. TODO Style
`# TODO(username): <actionable note>` — Keep them specific, not vague. Use sparingly.

---
## 18. Consistency Clause
If existing code slightly diverges but is internally consistent, **match local style** unless refactoring that region. New files must follow this document fully.

---
## 19. Copilot Behavior Directives
When generating Bash code in this repo:
1. Start with correct shebang & description if creating a new script.
2. Use the function header template where appropriate.
3. Default to safe quoting & arrays; assume inputs may contain spaces.
4. Prefer builtins & parameter expansion over spawning external tools (e.g., avoid subshell `sed` for simple prefix/suffix edits).
5. Provide meaningful error messages to stderr and propagate exit codes.
6. Keep lines ≤80 chars unless a single long literal (URL/path) — if longer, consider a here-doc or wrapping.
7. Suggest refactoring if a script seems to be growing beyond shell’s ergonomic limits (≥ ~100–150 lines complex logic).
8. Reject user prompts for unsafe patterns (eval misuse, unquoted globs) by proposing safer alternatives.

---
## 20. Quick Compliance Checklist (Copilot Internal)
Before completing a block, ensure:
| Aspect | Check |
| ------ | ----- |
| Shebang | `#!/bin/bash` present (top) |
| Options | `set -Eeuo pipefail` (if script body > trivial) |
| Constants | Uppercase + `readonly` |
| Functions | Grouped, `main` last, invoked |
| Quoting | All expansions quoted unless justified |
| Arrays | Used for argument lists / flag building |
| Tests | `[[ ... ]]` used; `-z`/`-n` for emptiness |
| Case | 2-space indentation; patterns formatted |
| Pipelines | Wrapped with backslashes when multiline |
| Arithmetic | `$(( ))` only |
| No Anti-Patterns | (eval/backticks/aliases/for-in-word-split) |
| Tooling Pass | Should satisfy `shfmt` & `shellcheck` |

---
## 21. Evolution
If a justified deviation is required (performance, clarity), accompany with a brief comment explaining the exception.

---
## 22. Example Minimal Script (Conforming)
```bash
#!/bin/bash
# Print a colorized hello message.
set -Eeuo pipefail

readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RESET='\033[0m'

#######################################
# Print greeting.
# Arguments:
#   1 - Name to greet.
# Outputs:
#   Writes greeting to stdout.
# Returns:
#   0 always.
#######################################
greet() {
  local name="${1:-world}"
  echo -e "${COLOR_GREEN}Hello, ${name}!${COLOR_RESET}"
}

main() {
  greet "${1:-}"
}

main "$@"
```

---
End of instructions. Copilot: Adhere to these rules when suggesting Bash code in this repository.
