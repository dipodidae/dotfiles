# 🚀 Tom's Dotfiles

A comprehensive development environment setup with zsh, Oh My Zsh, custom themes, plugins, and productivity tools.

## ⚡ Quick Install

**One-liner installation** (perfect for fresh systems like Raspberry Pi):

```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```

## 📦 What's Included

### 🐚 Shell Environment
- **Zsh** as the default shell
- **Oh My Zsh** framework
- **Pure prompt** - Clean, fast prompt theme
- **Enhanced plugins**:
  - `zsh-autosuggestions` - Fish-like autosuggestions
  - `zsh-syntax-highlighting` - Command syntax highlighting
  - `zsh-z` - Smart directory jumping

### 🟢 Node.js Development
- **NVM** (Node Version Manager)
- **Node.js LTS** automatically installed
- **ni** - Universal package manager (`ni`, `nr`, `nx`, `nu`, `nun`)
- **pnpm** - Fast, disk space efficient package manager
- **Package manager aliases** and shortcuts

### 🔧 Development Tools
- **Git** with enhanced aliases and utilities
- **Project management** functions
- **Smart commit** messages
- **Development cluster** management (SpendCloud specific)

### 🎯 Productivity Features
- **Directory navigation** shortcuts
- **Fuzzy project** switching
- **Repository cloning** utilities
- **Help system** with command reference

## 🛠️ Manual Installation

If you prefer to clone and run locally:

```bash
git clone https://github.com/dipodidae/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

## 📋 Installation Options

```bash
./install.sh --help           # Show help
./install.sh --dry-run        # Preview what will be installed
./install.sh --skip-packages  # Skip system package installation
```

## 🔄 Features

### Smart Installation
- ✅ **Cross-platform** support (Ubuntu, macOS, etc.)
- ✅ **Automatic backups** of existing configs
- ✅ **Error handling** with detailed logging
- ✅ **Retry logic** for network operations
- ✅ **Non-destructive** installation

### Development Workflow
- ✅ **Universal package manager** commands
- ✅ **Git workflow** optimization
- ✅ **Project switching** and navigation
- ✅ **Smart commit** message generation
- ✅ **Database migration** tools (SpendCloud)

### Shell Enhancement
- ✅ **Pure prompt** with git integration
- ✅ **Auto-suggestions** based on history
- ✅ **Syntax highlighting** for commands
- ✅ **Directory jumping** with z algorithm
- ✅ **Comprehensive help** system

## 📁 File Structure

```
dotfiles/
├── install.sh           # Main installation script
├── .zshrc              # Zsh configuration
├── .gitconfig          # Git configuration (optional)
├── .vimrc              # Vim configuration (optional)
└── README.md           # This file
```

## 🎯 Usage Examples

### After Installation

```bash
# Get help on available commands
help

# Navigate to development projects
d project-name          # Go to ~/development/project-name

# Smart git operations
commit                   # Smart commit with auto-generated message
switch main             # Switch to main/master branch
gp                      # Git push

# Universal package management
ni                      # Install dependencies (auto-detects npm/yarn/pnpm/bun)
nr start               # Run start script
nx eslint              # Execute package binaries
nu                     # Update dependencies
nun package            # Uninstall packages
pn                     # pnpm shortcut (fast package manager)
s                      # Start development server
b                      # Build project
t                      # Run tests

# Project management
proj                    # Fuzzy find and switch to any project
clone_to d user/repo    # Clone to development directory
```

### SpendCloud Specific

```bash
cluster                 # Start development cluster
migrate                 # Run database migrations
sc                      # Navigate to SpendCloud project
```

## 🔍 Customization

The `.zshrc` file is heavily documented and modular. You can:

1. **Modify aliases** in the respective sections
2. **Add custom functions** in the utilities section
3. **Configure paths** for your specific setup
4. **Add project-specific** shortcuts

## 🚨 Dangerous Commands

### ⚠️ Immediate .zshrc Overwrite

If the repository is ahead of your local `.zshrc` and you want to **immediately overwrite** your home folder's `.zshrc` with the latest version from GitHub:

```bash
# ⚠️ WARNING: This will IMMEDIATELY overwrite ~/.zshrc without backup!
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/.zshrc > ~/.zshrc && source ~/.zshrc
```

**Alternative with backup:**
```bash
# Safer option - creates backup first
cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d-%H%M%S) && curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/.zshrc > ~/.zshrc && source ~/.zshrc
```

**Local repository sync:**
```bash
# If you have the repo locally and want to sync immediately
cp /home/tom/projects/dotfiles/.zshrc ~/.zshrc && source ~/.zshrc
```

> **⚠️ Use these commands carefully!** They will overwrite your current `.zshrc` without confirmation.

## 🚨 Troubleshooting

### Installation Issues
- Check the log file: `~/.dotfiles-install.log`
- Ensure internet connectivity
- Verify git is installed: `git --version`

### Plugin Issues
- Reload configuration: `source ~/.zshrc`
- Check plugin directories: `ls ~/.oh-my-zsh/custom/plugins/`

### Shell Issues
- Verify zsh is default: `echo $SHELL`
- Change shell manually: `chsh -s $(which zsh)`

## 📝 Requirements

### Minimum Requirements
- **Linux/macOS** operating system
- **Internet connection** for downloads
- **curl** and **git** for installation

### Supported Systems
- ✅ Ubuntu/Debian (apt)
- ✅ macOS (homebrew)
- ✅ Arch Linux (pacman)
- ✅ RHEL/CentOS (yum)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test the installation on a fresh system
4. Submit a pull request

## 📄 License

MIT License - Feel free to use and modify for your own dotfiles!

---

## 🎉 Quick Start for New Systems

Perfect for setting up a fresh Raspberry Pi or server:

```bash
# Run the one-liner
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash

# Restart your terminal
exec zsh

# Enjoy your enhanced development environment!
help
```

**Happy coding!** 🚀
