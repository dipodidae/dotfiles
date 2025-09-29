<div align="center">

# dotfiles

Lean, repeatable developer shell bootstrap (Zsh + modern JS & CLI tooling) with an optional domain module.

![Shell Lint](https://github.com/dipodidae/dotfiles/actions/workflows/shellcheck.yml/badge.svg)

</div>

---

## Table of Contents

1. What & Why
2. Features
3. Quick Start
4. Optional SpendCloud Module
5. Built‑in Help System (Dual Mode)
6. Included Tooling Overview
7. Style, Lint & Quality Gates
8. Common Commands (Cheat Sheet)
9. Safety & Destructive Guards
10. Customization & Local Overrides

---

## 1. What & Why

These dotfiles provision a fast, idempotent development shell that:

* Minimizes manual setup: one command installer, safe re-runs.
* Encapsulates opinionated aliases & functions for daily Git / JS / navigation tasks.
* Enforces consistent shell script quality (style + lint + heuristic audits).
* Provides an opt‑in domain module ("SpendCloud") that cleanly layers extra aliases & functions without polluting a generic environment.

## 2. Features

Core (always available):
* Zsh + Oh My Zsh + Pure prompt (sub‑second load path)
* Plugins: autosuggestions, syntax highlighting, z, you-should-use
* Git & GitHub helpers: rich alias set, PR workflow, diff enhancements
* Node toolchain: NVM (LTS install), pnpm, `ni`/`nr` universal scripts, diff-so-fancy
* Python: pyenv bootstrap (best‑effort; skips gracefully if deps missing)
* fzf integration (with fd / bat / tree when present)
* `glow`-powered in-terminal documentation (fallback to `cat`)
* Self-documenting functions (header blocks + consistent patterns)
* Automated backups of replaced dotfiles: `~/.dotfiles-backup-*`

Optional (activated only when requested):
* SpendCloud / Proactive Frame development helpers (`cluster`, `migrate`, `nuke`, project aliases)
* Safe destructive guard rails (confirmation + environment gating)

## 3. Quick Start

Remote curl install (non-interactive):
```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
exec zsh
help          # Shows minimal or full help automatically
```

Manual clone (symlink mode):
```bash
git clone https://github.com/dipodidae/dotfiles.git
cd dotfiles
./install.sh
exec zsh
```

Idempotent: rerunning `./install.sh` updates components without clobbering local overrides.

## 4. Optional SpendCloud Module

Isolated in `~/.zsh/spend-cloud.optional.zsh`; loads only when one of these is true:
```bash
export ENABLE_SPEND_CLOUD=1   # before starting shell
# or
enable-spend-cloud            # inside an interactive shell
```
Disable any time:
```bash
disable-spend-cloud
```
Adds:
* Project nav aliases: `sc` `scapi` `scui` `pf` `capi` `cui` `cpf`
* Cluster lifecycle: `cluster [--rebuild|stop|logs|help]`
* Migrations: `migrate <mode>` (grouped, debug, targeted, rollback)
* Guarded cleanup: `nuke` (env + double confirmation)

All outputs preserve strict I/O contracts for reliable scripting.

## 5. Built‑in Help System (Dual Mode)

Command: `help`

| Mode | Trigger | File | Contents |
|------|---------|------|----------|
| Minimal | SpendCloud not enabled | `~/.zshrc.help.minimal.md` | Core aliases & workflows |
| Full | Module enabled/loaded | `~/.zshrc.help.md` | Adds cluster, migration & domain shortcuts |

Uses `glow` if installed; otherwise falls back to plain `cat`.

## 6. Included Tooling Overview

| Area | Tooling | Notes |
|------|---------|-------|
| Prompt | Pure | Fast async git status |
| Git Enhancements | diff-so-fancy, gh | Rich diffs & PR commands |
| Package Managers | pnpm + `ni`/`nr` | Unified script runner regardless of lockfile |
| Fuzzy Search | fzf + fd/bat/tree | Auto-integrated enhancements |
| Python | pyenv | Latest stable (best-effort install) |
| Docs | glow | Render Markdown help |
| Shell Quality | ShellCheck, shfmt, audit | Consistency & safety |

## 7. Style, Lint & Quality Gates

Pragmatic subset of Google Shell Style:
* Central config: `.shellcheckrc`, `.shfmt.conf`
* Bash scripts (in `lib/` + `scripts/`) use `#!/bin/bash` and `main()` pattern when non-trivial.
* Heuristic audit (`scripts/audit-shell-style.sh`) checks header blocks, `main()` presence, oversize hints.

Local quality suite:
```bash
scripts/fix-shell.sh          # Format + advisory lint
scripts/lint-shell.sh         # Strict ShellCheck
scripts/audit-shell-style.sh  # Heuristic checks
```

Optional pre-commit:
```bash
pre-commit install --install-hooks
```

## 8. Common Commands (Cheat Sheet)

```bash
# Package / scripts
s / b / t / w / c   # start, build, test, watch, typecheck
lint / lintf        # lint & auto-fix

# Git
gs / gcm / gp       # status / commit / push
gd / gdc            # diff (working / staged)
glp 15              # last 15 commits
pr ls / pr 123      # list PRs / checkout PR 123

# Navigation
development proj     # cd ~/development/proj
dir newthing        # mkdir + cd

# Clone shortcuts
cloned user/repo    # clone to ~/development + open VSCode

# Help
enable-spend-cloud && help  # full domain help
help                      # minimal or full automatically
```

When module enabled:
```bash
cluster --rebuild    # rebuild + start dev cluster
migrate debug         # per-group migration run
nuke --verify         # safe read-only analysis
```

## 9. Safety & Destructive Guards

| Feature | Safeguard |
|---------|-----------|
| `install.sh` | Timestamped backups of replaced dotfiles |
| `nuke` | Requires `ENABLE_NUKE=1` + dual confirmations |
| Cluster cleanup | Controlled regex for container selection |
| Color output | Auto-disables when not a TTY or `NO_COLOR` set |

## 10. Customization & Local Overrides

Add personal changes in `~/.zshrc.local` (never overwritten). Re-run installer safely anytime.

Disable domain layer per session:
```bash
disable-spend-cloud
```

---

> TL;DR: Run the installer, `exec zsh`, type `help`; optionally `enable-spend-cloud` for domain tooling.
