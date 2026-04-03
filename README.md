# Dotfiles

Modular dotfiles installer and Zsh configuration for dev environments. One command provisions your tools, shell, and secrets on a fresh machine.

## Quick Start

Bootstrap a new machine from scratch:

```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```

Or run locally after cloning:

```bash
git clone https://github.com/dipodidae/dotfiles.git ~/clones/dotfiles
cd ~/clones/dotfiles
./install.sh
```

### Options

```
./install.sh --dry-run         # Preview without making changes
./install.sh --skip-packages   # Skip system package installs
./install.sh --skip-python     # Skip pyenv/Python setup
./install.sh --skip-secrets    # Skip secrets decryption
```

## What Gets Installed

| Category | Tools |
|----------|-------|
| **Shell** | Zsh, Oh My Zsh, Pure prompt, 8 plugins |
| **Node.js** | NVM, Node LTS, pnpm, ni, diff-so-fancy |
| **Python** | pyenv, latest stable Python |
| **Utilities** | fzf, bat, fd, tree, glow, GitHub CLI |
| **Secrets** | age (passphrase-based encryption) |

## Supported Platforms

- Debian / Ubuntu (apt)
- Red Hat / Fedora (dnf/yum)
- Arch Linux (pacman)
- macOS (Homebrew)

## Architecture

The installer sources modular libraries from `lib/` in a defined order, then runs each setup step sequentially:

```
install.sh
  ├── lib/logging.sh     # Colored, timestamped output
  ├── lib/core.sh        # OS detection, dry-run, retry logic
  ├── lib/fs.sh          # Backups, symlinks, directory helpers
  ├── lib/pkg.sh         # Cross-platform package management
  ├── lib/python.sh      # pyenv + Python build
  ├── lib/node.sh        # NVM + Node.js + npm globals
  ├── lib/dev_tools.sh   # fzf, bat, fd, glow, gh
  ├── lib/zsh.sh         # Oh My Zsh, Pure prompt, plugins
  ├── lib/secrets.sh     # age encrypt/decrypt
  └── lib/system.sh      # Base packages, self-test, summary
```

Each module exposes namespaced functions (e.g. `pkg::install`, `node::setup`) and has no side effects when sourced. All state-changing operations go through `core::run` to support `--dry-run` mode.

## Shell Configuration

The `.zshrc` provides a curated set of aliases and functions:

- **Git** — 40+ aliases (`gs`, `ga`, `gc`, `gp`, `grb`, `gl`, `pr`, etc.)
- **Node.js** — shortcuts via ni (`s`=start, `d`=dev, `b`=build, `t`=test)
- **Navigation** — `development`, `repros`, `forks`, `projects` directory helpers
- **Clone helpers** — `clone`, `cloned`, `cloner`, `clonef` (clone + cd + open editor)
- **Help** — run `help` for a built-in reference rendered with glow

Extend locally with `~/.zshrc.local` (not tracked).

## Secrets Management

Secrets are encrypted with [age](https://github.com/FiloSottile/age) using passphrase-based encryption and stored safely in the repo.

`secrets/manifest.txt` maps encrypted files to their destinations:

```
ssh_key.age:~/.ssh/id_ed25519:600
ssh_config.age:~/.ssh/config:644
```

**Encrypt** new secrets:

```bash
./make-secrets.sh
```

**Decrypt** happens automatically during install, prompting for the passphrase.

## Development

```bash
make lint            # shellcheck + shfmt + zsh -n + style audit (matches CI)
make format          # Auto-format all shell files
make format-check    # Check formatting without modifying
```

> [!NOTE]
> The canonical lint pipeline is `./scripts/lint-shell.sh` — CI runs exactly this script.
