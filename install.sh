#!/bin/bash
set -euo pipefail # Exit on error, undefined variables, and pipe failures
# Configuration
readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${HOME}/.dotfiles-install.log"
readonly NVM_VERSION="v0.40.3"
readonly BACKUP_DIR
BACKUP_DIR="${HOME}/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
readonly DOTFILES_REPO="https://github.com/dipodidae/dotfiles.git"
readonly DOTFILES_RAW="https://raw.githubusercontent.com/dipodidae/dotfiles/main"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# ────────────────────────────────────────────────────────────────────────────────
# 🛠️  UTILITY FUNCTIONS
# ────────────────────────────────────────────────────────────────────────────────

# Logging function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >>"$LOG_FILE"
}

# Print functions with logging
print_header() {
  echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${PURPLE}║${NC} $1 ${PURPLE}║${NC}"
  echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
  log "HEADER: $1"
}

print_step() {
  echo -e "${BLUE}🔵${NC} $1"
  log "STEP: $1"
}

print_success() {
  echo -e "${GREEN}✅${NC} $1"
  log "SUCCESS: $1"
}

print_warning() {
  echo -e "${YELLOW}⚠️${NC}  $1"
  log "WARNING: $1"
}

print_error() {
  echo -e "${RED}❌${NC} $1" >&2
  log "ERROR: $1"
}

print_info() {
  echo -e "${CYAN}ℹ️${NC}  $1"
  log "INFO: $1"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if we're running from a remote source (piped from curl)
is_remote_install() {
  [[ ! -f "$SCRIPT_DIR/.zshrc" && ! -d "$SCRIPT_DIR/.git" ]]
}

# Download dotfiles repository
download_dotfiles() {
  print_step "Downloading dotfiles repository..."

  local dotfiles_dir="$HOME/.dotfiles-temp"

  # Clean up any existing temp directory
  [[ -d "$dotfiles_dir" ]] && rm -rf "$dotfiles_dir"

  if safe_git_clone "$DOTFILES_REPO" "$dotfiles_dir"; then
    print_success "Dotfiles repository downloaded"
    echo "$dotfiles_dir"
  else
    print_error "Failed to download dotfiles repository"
    return 1
  fi
}

# Download a single file from the repository
download_file() {
  local file_path="$1"
  local target_path="$2"
  local max_retries=3
  local retry_count=0

  while [[ $retry_count -lt $max_retries ]]; do
    if curl -fsSL "$DOTFILES_RAW/$file_path" -o "$target_path" 2>/dev/null; then
      return 0
    else
      ((retry_count++))
      if [[ $retry_count -lt $max_retries ]]; then
        print_warning "Download failed, retrying ($retry_count/$max_retries)..."
        sleep 2
      fi
    fi
  done

  print_error "Failed to download $file_path after $max_retries attempts"
  return 1
}

# Detect OS and package manager
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command_exists apt; then
      echo "debian"
    elif command_exists yum; then
      echo "redhat"
    elif command_exists pacman; then
      echo "arch"
    else
      echo "linux-unknown"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

# Backup existing files
backup_file() {
  local file="$1"
  if [[ -f "$file" || -d "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -r "$file" "$BACKUP_DIR/"
    print_info "Backed up $(basename "$file") to $BACKUP_DIR"
    log "BACKUP: $file -> $BACKUP_DIR"
  fi
}

# Safe git clone with retry
safe_git_clone() {
  local repo_url="$1"
  local target_dir="$2"
  local max_retries=3
  local retry_count=0

  while [[ $retry_count -lt $max_retries ]]; do
    if git clone "$repo_url" "$target_dir" 2>/dev/null; then
      return 0
    else
      ((retry_count++))
      if [[ $retry_count -lt $max_retries ]]; then
        print_warning "Clone failed, retrying ($retry_count/$max_retries)..."
        sleep 2
      fi
    fi
  done

  print_error "Failed to clone $repo_url after $max_retries attempts"
  return 1
}

# ────────────────────────────────────────────────────────────────────────────────
# 🧹 CLEANUP AND SETUP
# ────────────────────────────────────────────────────────────────────────────────

cleanup_on_exit() {
  if [[ $? -ne 0 ]]; then
    print_error "Installation failed. Check log file: $LOG_FILE"
    if [[ -d "$BACKUP_DIR" ]]; then
      print_info "Backups are available in: $BACKUP_DIR"
    fi
  fi
}

trap cleanup_on_exit EXIT

# Initialize
initialize() {
  print_header "🚀 INITIALIZING DOTFILES INSTALLATION"

  # Show installation method
  if is_remote_install; then
    echo -e "${CYAN}🌐 Remote installation detected${NC}"
    echo -e "${WHITE}Repository:${NC} $DOTFILES_REPO"
    echo ""
  else
    echo -e "${CYAN}📁 Local installation detected${NC}"
  fi

  # Create log file
  touch "$LOG_FILE"
  log "Installation started by $(whoami) on $(hostname)"
  log "Installation method: $(is_remote_install && echo 'remote' || echo 'local')"

  # Check prerequisites
  print_step "Checking prerequisites..."

  check_internet
  print_success "Internet connection verified"

  local os_type
  os_type=$(detect_os)
  print_info "Detected OS: $os_type"
  log "OS_TYPE: $os_type"

  if [[ "$os_type" == "unknown" || "$os_type" == "linux-unknown" ]]; then
    print_error "Unsupported operating system"
    exit 1
  fi

  export OS_TYPE="$os_type"
}

# ────────────────────────────────────────────────────────────────────────────────
# 📦 PACKAGE INSTALLATION
# ────────────────────────────────────────────────────────────────────────────────

install_base_packages() {
  print_header "📦 INSTALLING BASE PACKAGES"

  case "$OS_TYPE" in
  "debian")
    print_step "Updating package lists..."
    if sudo apt update; then
      print_success "Package lists updated"
    else
      print_error "Failed to update package lists"
      return 1
    fi

    print_step "Installing zsh and git..."
    if sudo apt install -y zsh git-core curl wget; then
      print_success "Base packages installed"
    else
      print_error "Failed to install base packages"
      return 1
    fi
    ;;
  "macos")
    if ! command_exists brew; then
      print_step "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    print_step "Installing zsh and git..."
    brew install zsh git curl wget
    print_success "Base packages installed"
    ;;
  *)
    print_warning "Unsupported OS for automatic package installation"
    print_info "Please manually install: zsh git curl wget"
    read -r -p "Press Enter when ready to continue..."
    ;;
  esac
}

# ────────────────────────────────────────────────────────────────────────────────
# � GITHUB CLI INSTALLATION
# ────────────────────────────────────────────────────────────────────────────────

install_github_cli() {
  print_header "🐙 INSTALLING GITHUB CLI"

  if command_exists gh; then
    print_info "GitHub CLI already installed"
    print_info "Current version: $(gh --version | head -n1)"
    return 0
  fi

  print_step "Installing GitHub CLI..."

  case "$OS_TYPE" in
  "debian")
    print_step "Setting up GitHub CLI repository for Debian/Ubuntu..."

    # Install prerequisites
    if ! command_exists wget; then
      sudo apt update && sudo apt install wget -y
    fi

    # Create keyring directory
    sudo mkdir -p -m 755 /etc/apt/keyrings

    # Download and install the signing key
    local temp_keyring
    temp_keyring=$(mktemp)

    if wget -nv -O"$temp_keyring" https://cli.github.com/packages/githubcli-archive-keyring.gpg; then
      cat "$temp_keyring" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      rm -f "$temp_keyring"
    else
      print_error "Failed to download GitHub CLI signing key"
      return 1
    fi

    # Add the repository
    sudo mkdir -p -m 755 /etc/apt/sources.list.d
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    # Update and install
    if sudo apt update && sudo apt install gh -y; then
      print_success "GitHub CLI installed successfully"
    else
      print_error "Failed to install GitHub CLI"
      return 1
    fi
    ;;

  "redhat")
    print_step "Installing GitHub CLI for Red Hat/Fedora..."

    if command_exists dnf; then
      # Try DNF5 first, then DNF4
      if dnf --version 2>/dev/null | grep -q "dnf5"; then
        print_info "Using DNF5..."
        sudo dnf install dnf5-plugins -y
        sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf install gh --repo gh-cli -y
      else
        print_info "Using DNF4..."
        sudo dnf install 'dnf-command(config-manager)' -y
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf install gh --repo gh-cli -y
      fi
    elif command_exists yum; then
      print_info "Using YUM..."
      if ! command_exists yum-config-manager; then
        sudo yum install yum-utils -y
      fi
      sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      sudo yum install gh -y
    else
      print_error "No compatible package manager found (dnf/yum)"
      return 1
    fi

    if command_exists gh; then
      print_success "GitHub CLI installed successfully"
    else
      print_error "GitHub CLI installation failed"
      return 1
    fi
    ;;

  "arch")
    print_step "Installing GitHub CLI for Arch Linux..."
    if sudo pacman -S --noconfirm github-cli; then
      print_success "GitHub CLI installed successfully"
    else
      print_error "Failed to install GitHub CLI"
      return 1
    fi
    ;;

  "macos")
    print_step "Installing GitHub CLI for macOS..."
    if command_exists brew; then
      if brew install gh; then
        print_success "GitHub CLI installed successfully"
      else
        print_error "Failed to install GitHub CLI via Homebrew"
        return 1
      fi
    else
      print_error "Homebrew not found. Please install Homebrew first."
      return 1
    fi
    ;;

  *)
    print_warning "Unsupported OS for automatic GitHub CLI installation"
    print_info "Please manually install GitHub CLI from: https://cli.github.com/"
    print_info "Or try one of these methods:"
    echo "  • Homebrew: brew install gh"
    echo "  • Conda: conda install gh --channel conda-forge"
    echo "  • Pre-compiled binary: https://github.com/cli/cli/releases"
    return 0
    ;;
  esac

  # Verify installation and show usage
  if command_exists gh; then
    print_success "GitHub CLI installation verified"
    print_info "Version: $(gh --version | head -n1)"
    echo ""
    print_info "📖 Quick start guide:"
    echo "  • Authenticate: ${CYAN}gh auth login${NC}"
    echo "  • Clone repo: ${CYAN}gh repo clone owner/repo${NC}"
    echo "  • Create PR: ${CYAN}gh pr create${NC}"
    echo "  • View issues: ${CYAN}gh issue list${NC}"
    echo "  • Get help: ${CYAN}gh help${NC}"
    echo ""
  else
    print_error "GitHub CLI installation verification failed"
    return 1
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# �🐚 ZSH CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

install_oh_my_zsh() {
  print_header "🐚 SETTING UP ZSH ENVIRONMENT"

  # Backup existing zsh config
  backup_file "$HOME/.zshrc"
  backup_file "$HOME/.oh-my-zsh"

  print_step "Installing Oh My Zsh..."

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    # Install Oh My Zsh non-interactively
    export RUNZSH=no # Don't run zsh after installation
    export CHSH=no   # Don't change shell automatically

    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
      print_success "Oh My Zsh installed successfully"
    else
      print_error "Failed to install Oh My Zsh"
      return 1
    fi
  else
    print_info "Oh My Zsh already installed"
  fi
}

install_pure_prompt() {
  print_step "Installing Pure prompt..."

  local pure_dir="$HOME/.zsh/pure"

  if [[ ! -d "$pure_dir" ]]; then
    mkdir -p "$HOME/.zsh"
    if safe_git_clone "https://github.com/sindresorhus/pure.git" "$pure_dir"; then
      print_success "Pure prompt installed"
    else
      print_error "Failed to install Pure prompt"
      return 1
    fi
  else
    print_info "Pure prompt already installed"
    # Update existing installation
    if (cd "$pure_dir" && git pull origin main >/dev/null 2>&1); then
      print_info "Pure prompt updated to latest version"
    fi
  fi
}

install_zsh_plugins() {
  print_step "Installing zsh plugins..."

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local plugins=(
    "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "zsh-z:https://github.com/agkozak/zsh-z"
  )

  for plugin_info in "${plugins[@]}"; do
    local plugin_name="${plugin_info%%:*}"
    local plugin_repo="${plugin_info##*:}"
    local plugin_dir="$zsh_custom/plugins/$plugin_name"

    if [[ ! -d "$plugin_dir" ]]; then
      print_step "Installing $plugin_name..."
      if safe_git_clone "$plugin_repo" "$plugin_dir"; then
        print_success "✅ Installed $plugin_name"
      else
        print_warning "Failed to install $plugin_name, skipping..."
      fi
    else
      print_info "⚠️  $plugin_name already installed"
      # Update existing plugin
      if (cd "$plugin_dir" && git pull origin main >/dev/null 2>&1) ||
        (cd "$plugin_dir" && git pull origin master >/dev/null 2>&1); then
        print_info "Updated $plugin_name"
      fi
    fi
  done
}

# ────────────────────────────────────────────────────────────────────────────────
# 🟢 NODE.JS SETUP
# ────────────────────────────────────────────────────────────────────────────────

install_nvm() {
  print_header "🟢 INSTALLING NODE.JS ENVIRONMENT"

  print_step "Installing NVM..."

  if [[ ! -d "$HOME/.nvm" ]]; then
    local nvm_install_script
    nvm_install_script=$(curl -s "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh")

    if [[ -n "$nvm_install_script" ]]; then
      if bash -c "$nvm_install_script"; then
        print_success "NVM installed successfully"

        # Source NVM for immediate use
        export NVM_DIR="$HOME/.nvm"
        # shellcheck disable=SC1091
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        if command_exists nvm; then
          print_step "Installing latest LTS Node.js..."
          if nvm install --lts && nvm use --lts; then
            print_success "Node.js LTS installed and activated"
            print_info "Node version: $(node --version)"
            print_info "NPM version: $(npm --version)"
          else
            print_warning "Failed to install Node.js via NVM"
          fi
        fi
      else
        print_error "Failed to install NVM"
        return 1
      fi
    else
      print_error "Failed to download NVM installation script"
      return 1
    fi
  else
    print_info "NVM already installed"

    # Try to update NVM
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if command_exists nvm; then
      print_info "Current NVM version: $(nvm --version)"
    fi
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# � PACKAGE MANAGERS SETUP
# ────────────────────────────────────────────────────────────────────────────────

install_package_managers() {
  print_header "📦 INSTALLING UNIVERSAL PACKAGE MANAGERS"

  # Ensure Node.js is available
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  if ! command_exists node; then
    print_error "Node.js not found. Cannot install package managers."
    return 1
  fi

  print_step "Installing ni (universal package manager)..."
  if npm install -g @antfu/ni; then
    print_success "ni installed successfully"
    print_info "Usage: ni (install), nr (run), nx (execute), nu (update), nun (uninstall)"
  else
    print_warning "Failed to install ni via npm"
  fi

  print_step "Installing pnpm (fast package manager)..."

  # Try multiple installation methods for pnpm
  local pnpm_installed=false

  # Method 1: Try npm installation first (most reliable if npm is working)
  if npm install -g pnpm@latest; then
    print_success "pnpm installed via npm"
    pnpm_installed=true
  else
    print_warning "npm installation failed, trying standalone script..."

    # Method 2: Use standalone script
    local pnpm_script
    pnpm_script=$(curl -fsSL https://get.pnpm.io/install.sh 2>/dev/null)

    if [[ -n "$pnpm_script" ]]; then
      if echo "$pnpm_script" | sh -; then
        print_success "pnpm installed via standalone script"
        pnpm_installed=true

        # Add pnpm to current session PATH
        export PNPM_HOME="$HOME/.local/share/pnpm"
        case ":$PATH:" in
          *":$PNPM_HOME:"*) ;;
          *) export PATH="$PNPM_HOME:$PATH" ;;
        esac
      else
        print_warning "Standalone script installation failed, trying Corepack..."
      fi
    fi

    # Method 3: Try Corepack if available
    if ! $pnpm_installed && command_exists corepack; then
      if corepack enable pnpm && corepack prepare pnpm@latest --activate; then
        print_success "pnpm installed via Corepack"
        pnpm_installed=true
      else
        print_warning "Corepack installation failed"
      fi
    fi
  fi

  if $pnpm_installed; then
    print_info "pnpm version: $(pnpm --version 2>/dev/null || echo 'Available after shell restart')"
    print_info "Tip: Use 'pn' as a shorter alias for pnpm (configured in .zshrc)"
  else
    print_error "Failed to install pnpm via all methods"
    print_info "You can manually install pnpm later with: npm install -g pnpm"
  fi

  print_step "Verifying package manager installations..."
  echo ""
  print_info "Available package managers:"
  command_exists npm && echo "  ✓ npm $(npm --version)"
  command_exists ni && echo "  ✓ ni (universal package manager)"
  command_exists pnpm && echo "  ✓ pnpm $(pnpm --version)" || echo "  ⚠ pnpm (restart shell to use)"
  command_exists yarn && echo "  ✓ yarn $(yarn --version)" || echo "  - yarn (not installed)"
  echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# �📁 DOTFILES CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

apply_dotfiles() {
  print_header "📁 APPLYING DOTFILES CONFIGURATION"

  local dotfiles_dir=""

  # Determine dotfiles location based on installation method
  if is_remote_install; then
    print_info "Remote installation detected - downloading dotfiles..."
    dotfiles_dir=$(download_dotfiles)
    if [[ -z "$dotfiles_dir" ]]; then
      return 1
    fi
  else
    # Local installation - find dotfiles directory
    if [[ -f "$SCRIPT_DIR/.zshrc" ]]; then
      dotfiles_dir="$SCRIPT_DIR"
    elif [[ -f "/home/tom/projects/dotfiles/.zshrc" ]]; then
      dotfiles_dir="/home/tom/projects/dotfiles"
    else
      print_error "Cannot find .zshrc file. Expected locations:"
      print_error "  - $SCRIPT_DIR/.zshrc"
      print_error "  - /home/tom/projects/dotfiles/.zshrc"
      return 1
    fi
  fi

  print_step "Applying configuration from $dotfiles_dir..."

  # Copy .zshrc
  if cp "$dotfiles_dir/.zshrc" "$HOME/.zshrc"; then
    print_success "Applied .zshrc configuration"
  else
    print_error "Failed to copy .zshrc"
    return 1
  fi

  # Apply other dotfiles if they exist
  local dotfiles=(".gitconfig" ".vimrc" ".tmux.conf")
  for dotfile in "${dotfiles[@]}"; do
    if [[ -f "$dotfiles_dir/$dotfile" ]]; then
      if cp "$dotfiles_dir/$dotfile" "$HOME/$dotfile"; then
        print_success "Applied $dotfile"
      else
        print_warning "Failed to copy $dotfile"
      fi
    fi
  done

  # Clean up temporary directory if it was a remote install
  if is_remote_install && [[ -d "$dotfiles_dir" && "$dotfiles_dir" == *".dotfiles-temp" ]]; then
    rm -rf "$dotfiles_dir"
    print_info "Cleaned up temporary files"
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# 🔧 POST-INSTALLATION
# ────────────────────────────────────────────────────────────────────────────────

configure_shell() {
  print_header "🔧 FINALIZING SHELL CONFIGURATION"

  # Change default shell to zsh if not already
  if [[ "$SHELL" != */zsh ]]; then
    print_step "Setting zsh as default shell..."
    local zsh_path
    zsh_path=$(command -v zsh)

    if [[ -n "$zsh_path" ]]; then
      if chsh -s "$zsh_path"; then
        print_success "Default shell changed to zsh"
      else
        print_warning "Failed to change default shell. You may need to run: chsh -s $zsh_path"
      fi
    else
      print_error "zsh not found in PATH"
    fi
  else
    print_info "zsh is already the default shell"
  fi
}

display_summary() {
  print_header "🎉 INSTALLATION COMPLETE"

  echo -e "${GREEN}✅ Successfully installed:${NC}"
  echo -e "   • Oh My Zsh with custom configuration"
  echo -e "   • Pure prompt theme"
  echo -e "   • Zsh plugins (autosuggestions, syntax highlighting, z)"
  echo -e "   • NVM and Node.js LTS"
  echo -e "   • Package managers (ni, pnpm)"
  echo -e "   • GitHub CLI (gh)"
  echo -e "   • Custom .zshrc configuration"
  echo ""

  if [[ -d "$BACKUP_DIR" ]]; then
    echo -e "${CYAN}💾 Backups saved to:${NC} $BACKUP_DIR"
    echo ""
  fi

  echo -e "${YELLOW}📝 Next steps:${NC}"
  echo -e "   1. ${WHITE}Restart your terminal${NC} or run: ${CYAN}exec zsh${NC}"
  echo -e "   2. Verify everything works: ${CYAN}help${NC}"
  echo -e "   3. Install additional tools as needed"
  echo ""

  if is_remote_install; then
    echo -e "${PURPLE}🚀 One-liner for future installs:${NC}"
    echo -e "${CYAN}curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash${NC}"
    echo ""
  fi

  echo -e "${BLUE}📋 Installation log:${NC} $LOG_FILE"
  echo -e "${PURPLE}🚀 Happy coding!${NC}"
  echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# 🎯 MAIN EXECUTION
# ────────────────────────────────────────────────────────────────────────────────

main() {
  # Handle command line arguments
  case "${1:-}" in
  --help | -h)
    echo "Tom's Dotfiles Installer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --dry-run      Show what would be installed without making changes"
    echo "  --skip-packages Skip system package installation"
    echo ""
    exit 0
    ;;
  --dry-run)
    echo "DRY RUN MODE - No changes will be made"
    export DRY_RUN=1
    ;;
  --skip-packages)
    export SKIP_PACKAGES=1
    ;;
  esac

  # Main installation flow
  initialize

  if [[ "${SKIP_PACKAGES:-}" != "1" ]]; then
    install_base_packages
  fi

  install_github_cli
  install_oh_my_zsh
  install_pure_prompt
  install_zsh_plugins
  install_nvm
  install_package_managers
  apply_dotfiles
  configure_shell
  display_summary

  log "Installation completed successfully"
}

# Run main function with all arguments
main "$@"
