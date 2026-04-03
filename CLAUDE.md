# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A modular dotfiles installer and Zsh configuration for Ubuntu/macOS dev environments. The installer provisions tools (Node, Python, fzf, bat, etc.), configures Zsh with Oh My Zsh + Pure prompt, and optionally decrypts age-encrypted secrets.

## Commands

```bash
make lint            # Run full lint suite (shellcheck + zsh -n + shfmt + style audit) — matches CI
make format          # Auto-format all shell files with shfmt
make format-check    # Check formatting without modifying files
make install         # Run the installer (install.sh)
```

The canonical lint pipeline is `./scripts/lint-shell.sh`. CI runs exactly this.

## Formatting & Linting

**shfmt** settings (`.shfmt.conf`): `-i 2 -ci -sr` (2-space indent, case-indent, space-redirect).

**shellcheck** config (`.shellcheckrc`): bash dialect, style severity, external sources enabled. Disabled codes: SC1071 (zsh syntax), SC1090 (dynamic source), SC2034 (unused vars in libs), SC2086 (word splitting — quoting enforced by convention), SC2119/SC2120 (function call patterns), SC2155 (declare+assign), SC2164 (cd without ||), SC2207 (mapfile preference).

**Style audit** (`scripts/audit-shell-style.sh`): Non-trivial functions need the `#######` doc header. Scripts >120 lines need a `main()` with tail call. Files >400 lines get a refactor warning.

## Architecture

**`install.sh`** is the entry point. It can bootstrap from a curl pipe (clones the repo first) or run directly. It sources all `lib/` modules in order, then calls `main()` which orchestrates setup steps sequentially.

**Module loading order** (defined in `install.sh`):
`logging` → `core` → `fs` → `pkg` → `python` → `node` → `dev_tools` → `zsh` → `secrets` → `system`

Each `lib/*.sh` module is a library of functions namespaced with `module::function_name` (e.g., `pkg::install`, `core::run`, `zsh::setup`). Modules are sourced — not executed — so they must not have top-level side effects.

**`core::run`** wraps all state-changing operations to support `--dry-run` mode.

**Secrets**: `age` passphrase-based encryption. `secrets/manifest.txt` maps `*.age` files to destination paths with permissions. `make-secrets.sh` encrypts, `lib/secrets.sh` decrypts at install time.

## Shell Coding Standards

Full standards are in `.github/copilot-instructions.md`. Key points:

- All scripts are Bash (`#!/bin/bash`) with `set -Eeuo pipefail` for non-trivial scripts
- Functions: `lower_snake_case`, namespaced as `module::function` in libraries
- Constants: `UPPER_SNAKE_CASE` + `readonly`
- Always double-quote expansions: `"${var}"`, `"$(cmd)"`, `"$@"`
- Use `[[ ... ]]` for tests, `$(( ... ))` for arithmetic, `$(...)` for command substitution
- Use arrays for argument/flag building, never string-splitting
- Split `local` declaration from assignment to preserve exit codes
- Guard pattern for errors: `if ! cmd; then error "msg"; return 1; fi`
- Use `lib/logging.sh` functions (`info`, `success`, `error`, `warn`) — not raw echo
- Global mutable state prefixed with `_` (e.g., `_PKG_APT_UPDATED`)
- Lines should be at most 80 characters

## Function Doc Header (required for non-trivial library functions)

```bash
#######################################
# Verb phrase summary.
# Globals:
#   VAR1
# Arguments:
#   1 - description
# Outputs:
#   Writes X to stdout.
# Returns:
#   0 on success, non-zero on failure.
#######################################
```

## Zsh Configuration

`.zshrc` is the interactive shell config (symlinked by the installer). It is Zsh, not Bash — shellcheck does not lint it. `.zshrc.help.md` provides in-shell help via the `help` command. Users extend via `~/.zshrc.local` (not tracked).
