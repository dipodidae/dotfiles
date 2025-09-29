<div align="center">

# dotfiles

Zsh shell + modern tooling, bootstrapped in one go.

![Shell Lint](https://github.com/dipodidae/dotfiles/actions/workflows/shellcheck.yml/badge.svg)

</div>

---

## Quick Start

Copy-paste this and you’re basically done:

```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```

That’s it. Rerun the installer any time — it just updates, never clobbers your local overrides.

---

## What You Get

* ⚡ **Fast Zsh**: Oh My Zsh + Pure prompt, sub-second load.
* 🧩 Plugins: autosuggestions, syntax highlighting, `z`, you-should-use.
* 🛠 Git helpers: rich alias set, PR workflow, diff-so-fancy.
* 📦 Node ready: NVM (LTS), pnpm, `ni`/`nr` for universal scripts.
* 🐍 Python bootstrap via pyenv (best effort).
* 🔎 fzf everywhere (with fd / bat / tree when present).
* 📖 In-terminal docs via `glow` (or `cat` fallback).
* 🔒 Safe installer: backs up your old dotfiles automatically.

---

## Built-in Help

Type `help` and you’ll either get:

Renders in-terminal with `glow`, falls back to plain text.

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
cloned user/repo     # clone to ~/development + open VSCode
```

---

## Customizing

Your own tweaks live in `~/.zshrc.local` (never touched).
Re-run installer whenever — it won’t overwrite local changes.

---

👉 TL;DR:

```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```
