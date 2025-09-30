<div align="center">

# dotfiles

Zsh shell + modern tooling, bootstrapped in one go.

![Shell Lint](https://github.com/dipodidae/dotfiles/actions/workflows/shellcheck.yml/badge.svg)

</div>

---

## Quick Start

Copy-paste this and you’re done:

```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```

---

## Development & Linting

This repo follows **one canonical linting pipeline** (defined in `.github/workflows/shellcheck.yml`).

### Local Development

```bash
# Run complete lint suite (matches CI)
make lint              # or: ./scripts/lint-shell.sh

# Auto-format all shell files
./scripts/format-shell.sh

# Check formatting only
./scripts/format-shell.sh --check
```

### Pre-commit Hooks (Optional)

```bash
pre-commit install     # Auto-lint on commit
pre-commit run --all-files
```

### What Gets Checked

1. **shellcheck (bash)** - main shell files
2. **shellcheck (zsh)** - advisory only
3. **shfmt** - formatting (`-i 2 -ci -sr`)
4. **audit** - Google Shell Style Guide heuristics

Local = CI = consistent.

Re-run the installer anytime — it updates safely and never overwrites your local overrides.

---

## What You Get

* ⚡ **Fast Zsh**: Oh My Zsh + Pure prompt, sub-second load
* 🧩 Plugins: autosuggestions, syntax highlighting, `z`, you-should-use
* 🛠 Git helpers: aliases, PR workflow, diff-so-fancy
* 📦 Node ready: NVM (LTS), pnpm, `ni`/`nr` for universal scripts
* 🐍 Python via pyenv (best effort)
* 🔎 fzf everywhere (with fd / bat / tree when present)
* 📖 In-terminal docs with `glow` (falls back to `cat`)
* 🔒 Safe installer: backs up your old dotfiles automatically

---

## Built-in Help

Type `help` in your shell:

* Renders with `glow` if available
* Falls back to plain text

---

## Cheat Sheet

```bash
# Packages / scripts
s / b / t / w / c    # start, build, test, watch, typecheck
lint / lintf         # lint & auto-fix

# Git
gs / gcm / gp        # status / commit / push
gd / gdc             # diff (working / staged)
glp 15               # last 15 commits
pr ls / pr 123       # list PRs / checkout PR

# Navigation
development proj     # cd ~/development/proj
dir newthing         # mkdir + cd

# Clone
cloned user/repo     # clone to ~/development + open in VSCode
```

---

## Customizing

Put your own tweaks in `~/.zshrc.local`.
Re-run the installer whenever — your local changes stay untouched.

---

👉 TL;DR:

```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```
