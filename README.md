## dotfiles

Lean, repeatable developer shell bootstrap (Zsh + Node + modern CLI tooling) with sane defaults and fast idempotent re-runs.

### Quick install (remote)
```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```

### Manual clone (local / symlink mode)
```bash
git clone https://github.com/dipodidae/dotfiles.git
cd dotfiles && ./install.sh
```

### What's included (auto-installed where possible)
- Zsh + Oh My Zsh + Pure prompt
- Zsh plugins: autosuggestions, syntax highlighting, z, you-should-use
- Git + handy aliases + hub -> gh alias (if hub missing)
- GitHub CLI (gh)
- NVM + Node LTS
- JS tooling: pnpm, ni (nr / nx / nu / nun), diff-so-fancy
- fzf + integration helpers (fd / bat / tree when packages available)
- pyenv + latest Python (best effort; skips silently if deps missing)
- glow (markdown viewer) for in-terminal help (if available)
- Safe backups of replaced dotfiles to `~/.dotfiles-backup-*`
- Clean, minimal color logging to `~/.dotfiles-install.log`

### Supported platforms
Debian/Ubuntu, Arch, RedHat (dnf/yum), macOS. Other Linux variants fall back to partial install (manual steps may be required).

### Script options
```bash
./install.sh --help
./install.sh --dry-run        # show actions only (no changes)
./install.sh --skip-packages  # skip system package manager usage
```

### Dry run example
```bash
./install.sh --dry-run | less
```

### After install
Restart your shell or run:
```bash
exec zsh
```
Then type:
```bash
help
```
for the inline help / cheat sheet.

### Common helper commands
```bash
d <name>      # jump to ~/development/<name>
proj          # fuzzy switch project
commit        # guided commit helper
gp            # git push shortcut
ni / nr / nx  # install / run / exec (universal)
```

### Update only .zshrc later (remote refresh)
```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/.zshrc > ~/.zshrc && \
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/.zshrc.help.md > ~/.zshrc.help.md && \
source ~/.zshrc
```

### Uninstall / revert pieces
Backups live in timestamped `~/.dotfiles-backup-*` directories. Manually restore from there if you want to revert a specific file.

### Troubleshooting
| Issue | What to do |
|-------|------------|
| Something failed mid-install | Check `~/.dotfiles-install.log` (timestamps + steps) |
| Missing tool after run | Re-run script (idempotent) or install manually |
| Shell still bash | `chsh -s $(command -v zsh)` then log out/in |
| Node not found | `source ~/.nvm/nvm.sh && nvm use --lts` |
| pyenv Python missing | Ensure build deps installed, then `pyenv install <version>` |

### Self-test
The script runs a lightweight self-test (core binaries + .zshrc presence). You can manually rerun key checks:
```bash
command -v zsh git curl gh fzf node || echo "Missing some tools"
```

### Logs
`~/.dotfiles-install.log` – append-only, safe to delete between runs.

### License
MIT

### TL;DR
Run the one-liner, `exec zsh`, then `help`.
