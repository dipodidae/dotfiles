## dotfiles

Minimal, fast setup for a productive Zsh + Node.js development shell.

### Install (one-liner)
```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```

### Core goodies
- Zsh + Oh My Zsh + pure prompt
- Plugins: autosuggestions, syntax highlighting, z (jump)
- NVM + Node LTS + pnpm + universal ni aliases
- Git + handy aliases (commit / switch / gp)
- Project + repo navigation helpers (proj, clone_to, d)

### Manual clone
```bash
git clone https://github.com/dipodidae/dotfiles.git
cd dotfiles && ./install.sh
```

### Script options
```bash
./install.sh --help | --dry-run | --skip-packages
```

### After install
Type: help

Common:
  d <name>      jump to ~/development/<name>
  proj          fuzzy switch project
  commit        smart commit msg
  gp            git push
  ni / nr / nx  install / run / exec

### Update .zshrc quickly
```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/.zshrc > ~/.zshrc && \
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/.zshrc.help.md > ~/.zshrc.help.md && \
source ~/.zshrc
```

### Troubleshoot
Log: ~/.dotfiles-install.log
Reload: source ~/.zshrc
Check shell: echo $SHELL

### License
MIT

### TL;DR
Run the one-liner, restart (exec zsh), type help.
