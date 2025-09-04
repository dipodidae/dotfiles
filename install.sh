#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                        TOM'S DOTFILES INSTALLER                              ║
# ║                    Comprehensive Development Environment Setup               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${HOME}/.dotfiles-install.log"
readonly DOTFILES_NVM_VERSION="v0.40.3"
# shellcheck disable=SC2155
readonly BACKUP_DIR="${HOME}/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
readonly DOTFILES_REPO="https://github.com/dipodidae/dotfiles.git"
readonly DOTFILES_RAW="https://raw.githubusercontent.com/dipodidae/dotfiles/main"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# ────────────────────────────────────────────────────────────────────────────────
# 🛠️ UTILITY FUNCTIONS
# ────────────────────────────────────────────────────────────────────────────────

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >>"$LOG_FILE"
}

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_remote_install() {
    [[ ! -f "$SCRIPT_DIR/.zshrc" && ! -d "$SCRIPT_DIR/.git" ]]
}

download_dotfiles() {
    print_step "Downloading dotfiles repository..."
    local dotfiles_dir="$HOME/.dotfiles-temp"
    [[ -d "$dotfiles_dir" ]] && rm -rf "$dotfiles_dir"
    if safe_git_clone "$DOTFILES_REPO" "$dotfiles_dir"; then
        print_success "Dotfiles repository downloaded"
        echo "$dotfiles_dir"
    else
        print_error "Failed to download dotfiles repository"
        return 1
    fi
}

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

backup_file() {
    local file="$1"
    if [[ -f "$file" || -d "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$file" "$BACKUP_DIR/"
        print_info "Backed up $(basename "$file") to $BACKUP_DIR"
        log "BACKUP: $file -> $BACKUP_DIR"
    fi
}

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

check_internet() {
    if ! curl -s --head --request GET https://github.com >/dev/null 2>&1; then
        print_error "No internet connection detected"
        exit 1
    fi
}

cleanup_on_exit() {
    if [[ $? -ne 0 ]]; then
        print_error "Installation failed. Check log file: $LOG_FILE"
        if [[ -d "$BACKUP_DIR" ]]; then
            print_info "Backups are available in: $BACKUP_DIR"
        fi
    fi
}

trap cleanup_on_exit EXIT

initialize() {
    print_header "🚀 INITIALIZING DOTFILES INSTALLATION"
    if is_remote_install; then
        echo -e "${CYAN}🌐 Remote installation detected${NC}"
        echo -e "${WHITE}Repository:${NC} $DOTFILES_REPO"
        echo ""
    else
        echo -e "${CYAN}📁 Local installation detected${NC}"
    fi
    touch "$LOG_FILE"
    log "Installation started by $(whoami) on $(hostname)"
    log "Installation method: $(is_remote_install && echo 'remote' || echo 'local')"
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
# 🐙 GITHUB CLI INSTALLATION
# ────────────────────────────────────────────────────────────────────────────────

install_github_cli() {
    print_header "🐙 INSTALLING GITHUB CLI"
    if command_exists gh; then
        print_info "Skipping GitHub CLI, already installed"
        print_info "Current version: $(gh --version | head -n1)"
        return 0
    fi
    print_step "Installing GitHub CLI..."
    case "$OS_TYPE" in
        "debian")
            print_step "Setting up GitHub CLI repository for Debian/Ubuntu..."
            if ! command_exists wget; then
                sudo apt update && sudo apt install wget -y
            fi
            sudo mkdir -p -m 755 /etc/apt/keyrings
            local temp_keyring
            temp_keyring=$(mktemp)
            if wget -nv -O"$temp_keyring" https://cli.github.com/packages/githubcli-archive-keyring.gpg; then
                sudo cat "$temp_keyring" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
                sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
                rm -f "$temp_keyring"
            else
                print_error "Failed to download GitHub CLI signing key"
                return 1
            fi
            sudo mkdir -p -m 755 /etc/apt/sources.list.d
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
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
            return 0
        ;;
    esac
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
# 🐚 ZSH CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

install_oh_my_zsh() {
    print_header "🐚 SETTING UP ZSH ENVIRONMENT"
    backup_file "$HOME/.zshrc"
    backup_file "$HOME/.oh-my-zsh"
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        print_step "Installing Oh My Zsh..."
        export RUNZSH=no
        export CHSH=no
        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
            print_success "Oh My Zsh installed successfully"
        else
            print_error "Failed to install Oh My Zsh"
            return 1
        fi
    else
        print_info "Skipping Oh My Zsh, already installed"
    fi
}

install_pure_prompt() {
    local pure_dir="$HOME/.zsh/pure"
    if [[ ! -d "$pure_dir" ]]; then
        print_step "Installing Pure prompt..."
        mkdir -p "$HOME/.zsh"
        if safe_git_clone "https://github.com/sindresorhus/pure.git" "$pure_dir"; then
            print_success "Pure prompt installed"
        else
            print_error "Failed to install Pure prompt"
            return 1
        fi
    else
        print_info "Skipping Pure prompt, already installed"
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
        "you-should-use:https://github.com/MichaelAquilina/zsh-you-should-use.git"
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
            print_info "Skipping $plugin_name, already installed"
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
    if [[ ! -d "$HOME/.nvm" ]]; then
        print_step "Installing NVM..."
        local nvm_install_script
        nvm_install_script=$(curl -s "https://raw.githubusercontent.com/nvm-sh/nvm/$DOTFILES_NVM_VERSION/install.sh")
        if [[ -n "$nvm_install_script" ]]; then
            if bash -c "$nvm_install_script"; then
                print_success "NVM installed successfully"
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
        print_info "Skipping NVM, already installed"
        export NVM_DIR="$HOME/.nvm"
        # shellcheck disable=SC1091
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        if command_exists nvm; then
            print_info "Current NVM version: $(nvm --version)"
        fi
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# 📦 PACKAGE MANAGERS SETUP
# ────────────────────────────────────────────────────────────────────────────────

install_package_managers() {
    print_header "📦 INSTALLING UNIVERSAL PACKAGE MANAGERS"
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    if ! command_exists node; then
        print_error "Node.js not found. Cannot install package managers."
        return 1
    fi
    if ! command_exists ni; then
        print_step "Installing ni (universal package manager)..."
        if npm install -g @antfu/ni; then
            print_success "ni installed successfully"
            print_info "Usage: ni (install), nr (run), nx (execute), nu (update), nun (uninstall)"
        else
            print_warning "Failed to install ni via npm"
        fi
    else
        print_info "Skipping ni, already installed"
    fi
    if ! command_exists pnpm; then
        print_step "Installing pnpm (fast package manager)..."
    local pnpm_installed=false
    if npm install -g pnpm@latest; then
        print_success "pnpm installed via npm"
        pnpm_installed=true
    else
        print_warning "npm installation failed, trying standalone script..."
        local pnpm_script
        pnpm_script=$(curl -fsSL https://get.pnpm.io/install.sh 2>/dev/null)
        if [[ -n "$pnpm_script" ]]; then
            if echo "$pnpm_script" | sh -; then
                print_success "pnpm installed via standalone script"
                pnpm_installed=true
                export PNPM_HOME="$HOME/.local/share/pnpm"
                case ":$PATH:" in
                    *":$PNPM_HOME:"*) ;;
                    *) export PATH="$PNPM_HOME:$PATH" ;;
                esac
            else
                print_warning "Standalone script installation failed, trying Corepack..."
            fi
        fi
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
    else
        print_info "Skipping pnpm, already installed"
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
# 🛠️ DEVELOPMENT TOOLS INSTALLATION
# ────────────────────────────────────────────────────────────────────────────────

install_development_tools() {
    print_header "🛠️ INSTALLING DEVELOPMENT TOOLS"
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install Homebrew (Linux) if not present
    if [[ "$OS_TYPE" == "debian" || "$OS_TYPE" == "redhat" || "$OS_TYPE" == "arch" ]]; then
        if ! command_exists brew; then
            print_step "Installing Homebrew for Linux..."
            if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
                # Try to find and source the Homebrew environment
                local brew_shellenv=""
                if [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
                    brew_shellenv="$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
                elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
                    brew_shellenv="$($HOME/.linuxbrew/bin/brew shellenv)"
                elif command -v brew >/dev/null 2>&1; then
                    brew_shellenv="$(brew shellenv)"
                fi

                if [[ -n "$brew_shellenv" ]]; then
                    eval "$brew_shellenv"
                    print_success "Homebrew installed successfully"
                else
                    print_warning "Homebrew installed but could not configure environment automatically"
                fi
            else
                print_warning "Failed to install Homebrew - some tools may not be available"
            fi
        else
            print_info "Skipping Homebrew, already installed"
        fi
    fi

    # Install Hub (GitHub CLI wrapper)
    if ! command_exists hub; then
        print_step "Installing Hub (GitHub CLI wrapper)..."
        # hub is deprecated and not supported on Linux arm64 via bottles; prefer gh
        local arch
        arch="$(uname -m)"
        if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && [[ "$OS_TYPE" != "macos" ]]; then
            print_warning "Skipping hub on ${arch} Linux (deprecated/no arm64 support). Using gh instead."
            if command_exists gh; then
                if ! grep -qE '(^|[[:space:]])alias[[:space:]]+hub=' "$HOME/.zshrc" 2>/dev/null; then
                    echo "alias hub='gh'" >> "$HOME/.zshrc"
                    print_info "Added alias: hub -> gh in .zshrc"
                fi
            fi
        else
            case "$OS_TYPE" in
                "debian")
                    if command_exists brew; then
                        if brew install hub || brew install --build-from-source hub; then :; else print_warning "Failed to install hub via Homebrew"; fi
                        elif command_exists apt; then
                        if sudo apt update && sudo apt install -y hub; then :; else print_warning "Failed to install hub via apt"; fi
                    fi
                ;;
                "redhat")
                    if command_exists brew; then
                        if brew install hub || brew install --build-from-source hub; then :; else print_warning "Failed to install hub via Homebrew"; fi
                        elif command_exists dnf; then
                        if sudo dnf install -y hub; then :; else print_warning "Failed to install hub via dnf"; fi
                        elif command_exists yum; then
                        if sudo yum install -y hub; then :; else print_warning "Failed to install hub via yum"; fi
                    fi
                ;;
                "arch")
                    if sudo pacman -S --noconfirm hub; then :; else print_warning "Failed to install hub via pacman"; fi
                ;;
                "macos")
                    if brew install hub || brew install --build-from-source hub; then :; else print_warning "Failed to install hub via Homebrew"; fi
                ;;
                *)
                    print_warning "Cannot install hub automatically on this system"
                ;;
            esac

            if command_exists hub; then
                print_success "Hub installed successfully"
            else
                print_warning "Hub not installed; gh is installed and recommended"
                if command_exists gh; then
                    if ! grep -qE '(^|[[:space:]])alias[[:space:]]+hub=' "$HOME/.zshrc" 2>/dev/null; then
                        echo "alias hub='gh'" >> "$HOME/.zshrc"
                        print_info "Added alias: hub -> gh in .zshrc"
                    fi
                fi
            fi
        fi
    else
        print_info "Skipping Hub, already installed"
    fi

    # Install FZF (Fuzzy Finder)
    if ! command_exists fzf; then
        print_step "Installing FZF (Fuzzy Finder)..."
        case "$OS_TYPE" in
            "debian")
                if command_exists brew; then
                    if brew install fzf; then
                        print_success "FZF installed via Homebrew"
                    else
                        print_warning "Failed to install fzf via Homebrew, trying apt..."
                        if sudo apt update && sudo apt install fzf -y; then
                            print_success "FZF installed via apt"
                        else
                            print_warning "Failed to install fzf via apt"
                        fi
                    fi
                else
                    if sudo apt update && sudo apt install fzf -y; then
                        print_success "FZF installed via apt"
                    else
                        print_warning "Failed to install fzf via apt"
                    fi
                fi
            ;;
            "redhat")
                if command_exists brew; then
                    if brew install fzf; then
                        print_success "FZF installed via Homebrew"
                    else
                        print_warning "Failed to install fzf via Homebrew, trying dnf/yum..."
                        if command_exists dnf; then
                            sudo dnf install fzf -y && print_success "FZF installed via dnf" || print_warning "Failed to install fzf via dnf"
                        elif command_exists yum; then
                            sudo yum install fzf -y && print_success "FZF installed via yum" || print_warning "Failed to install fzf via yum"
                        else
                            print_warning "No compatible package manager found"
                        fi
                    fi
                else
                    if command_exists dnf; then
                        sudo dnf install fzf -y && print_success "FZF installed via dnf" || print_warning "Failed to install fzf via dnf"
                    elif command_exists yum; then
                        sudo yum install fzf -y && print_success "FZF installed via yum" || print_warning "Failed to install fzf via yum"
                    else
                        print_warning "No compatible package manager found"
                    fi
                fi
            ;;
            "arch")
                if sudo pacman -S fzf --noconfirm; then
                    print_success "FZF installed via pacman"
                else
                    print_warning "Failed to install fzf via pacman"
                fi
            ;;
            "macos")
                if brew install fzf; then
                    print_success "FZF installed via Homebrew"
                else
                    print_warning "Failed to install fzf via Homebrew"
                fi
            ;;
            *)
                if command_exists brew; then
                    brew install fzf && print_success "FZF installed via Homebrew" || print_warning "Failed to install fzf via Homebrew"
                else
                    print_warning "Cannot install fzf automatically on this system"
                    print_info "Please install fzf manually: https://github.com/junegunn/fzf#installation"
                fi
            ;;
        esac
        if command_exists fzf; then
            print_success "FZF installation verified"
            print_info "Version: $(fzf --version 2>/dev/null || echo 'Available after shell restart')"
        else
            print_warning "FZF installation verification failed"
        fi
    else
        print_info "Skipping FZF, already installed"
        print_info "Current version: $(fzf --version 2>/dev/null || echo 'Available after shell restart')"
    fi

    # Install additional tools that complement fzf
    if ! command_exists fd; then
        print_step "Installing fd (better find alternative for fzf)..."
        case "$OS_TYPE" in
            "debian")
                if command_exists brew; then
                    if brew install fd; then
                        print_success "fd installed via Homebrew"
                    else
                        print_warning "Failed to install fd via Homebrew, trying apt..."
                        if sudo apt update && sudo apt install fd-find -y; then
                            # On Debian/Ubuntu, fd is called fd-find to avoid conflicts
                            if ! command_exists fd && command_exists fdfind; then
                                echo 'alias fd=fdfind' >> "$HOME/.zshrc"
                                print_success "fd (fd-find) installed via apt with alias"
                            else
                                print_success "fd installed via apt"
                            fi
                        else
                            print_warning "Failed to install fd via apt"
                        fi
                    fi
                else
                    if sudo apt update && sudo apt install fd-find -y; then
                        if ! command_exists fd && command_exists fdfind; then
                            echo 'alias fd=fdfind' >> "$HOME/.zshrc"
                            print_success "fd (fd-find) installed via apt with alias"
                        else
                            print_success "fd installed via apt"
                        fi
                    else
                        print_warning "Failed to install fd via apt"
                    fi
                fi
            ;;
            "redhat")
                if command_exists brew; then
                    brew install fd && print_success "fd installed via Homebrew" || print_warning "Failed to install fd via Homebrew"
                elif command_exists dnf; then
                    sudo dnf install fd-find -y && print_success "fd installed via dnf" || print_warning "Failed to install fd via dnf"
                elif command_exists yum; then
                    sudo yum install fd-find -y && print_success "fd installed via yum" || print_warning "Failed to install fd via yum"
                fi
            ;;
            "arch")
                sudo pacman -S fd --noconfirm && print_success "fd installed via pacman" || print_warning "Failed to install fd via pacman"
            ;;
            "macos")
                brew install fd && print_success "fd installed via Homebrew" || print_warning "Failed to install fd via Homebrew"
            ;;
            *)
                if command_exists brew; then
                    brew install fd && print_success "fd installed via Homebrew" || print_warning "Failed to install fd via Homebrew"
                else
                    print_warning "Cannot install fd automatically on this system"
                fi
            ;;
        esac
    else
        print_info "Skipping fd, already installed"
    fi

    # Install bat for better file previews in fzf
    if ! command_exists bat; then
        print_step "Installing bat (better cat with syntax highlighting)..."
        case "$OS_TYPE" in
            "debian")
                if command_exists brew; then
                    if brew install bat; then
                        print_success "bat installed via Homebrew"
                    else
                        print_warning "Failed to install bat via Homebrew, trying apt..."
                        if sudo apt update && sudo apt install bat -y; then
                            # On older Debian/Ubuntu, bat might be called batcat
                            if ! command_exists bat && command_exists batcat; then
                                echo 'alias bat=batcat' >> "$HOME/.zshrc"
                                print_success "bat (batcat) installed via apt with alias"
                            else
                                print_success "bat installed via apt"
                            fi
                        else
                            print_warning "Failed to install bat via apt"
                        fi
                    fi
                else
                    if sudo apt update && sudo apt install bat -y; then
                        if ! command_exists bat && command_exists batcat; then
                            echo 'alias bat=batcat' >> "$HOME/.zshrc"
                            print_success "bat (batcat) installed via apt with alias"
                        else
                            print_success "bat installed via apt"
                        fi
                    else
                        print_warning "Failed to install bat via apt"
                    fi
                fi
            ;;
            "redhat")
                if command_exists brew; then
                    brew install bat && print_success "bat installed via Homebrew" || print_warning "Failed to install bat via Homebrew"
                elif command_exists dnf; then
                    sudo dnf install bat -y && print_success "bat installed via dnf" || print_warning "Failed to install bat via dnf"
                elif command_exists yum; then
                    sudo yum install bat -y && print_success "bat installed via yum" || print_warning "Failed to install bat via yum"
                fi
            ;;
            "arch")
                sudo pacman -S bat --noconfirm && print_success "bat installed via pacman" || print_warning "Failed to install bat via pacman"
            ;;
            "macos")
                brew install bat && print_success "bat installed via Homebrew" || print_warning "Failed to install bat via Homebrew"
            ;;
            *)
                if command_exists brew; then
                    brew install bat && print_success "bat installed via Homebrew" || print_warning "Failed to install bat via Homebrew"
                else
                    print_warning "Cannot install bat automatically on this system"
                fi
            ;;
        esac
    else
        print_info "Skipping bat, already installed"
    fi

    # Install tree for directory previews
    if ! command_exists tree; then
        print_step "Installing tree (directory structure viewer)..."
        case "$OS_TYPE" in
            "debian")
                if command_exists brew; then
                    brew install tree && print_success "tree installed via Homebrew" || print_warning "Failed to install tree via Homebrew"
                else
                    sudo apt update && sudo apt install tree -y && print_success "tree installed via apt" || print_warning "Failed to install tree via apt"
                fi
            ;;
            "redhat")
                if command_exists brew; then
                    brew install tree && print_success "tree installed via Homebrew" || print_warning "Failed to install tree via Homebrew"
                elif command_exists dnf; then
                    sudo dnf install tree -y && print_success "tree installed via dnf" || print_warning "Failed to install tree via dnf"
                elif command_exists yum; then
                    sudo yum install tree -y && print_success "tree installed via yum" || print_warning "Failed to install tree via yum"
                fi
            ;;
            "arch")
                sudo pacman -S tree --noconfirm && print_success "tree installed via pacman" || print_warning "Failed to install tree via pacman"
            ;;
            "macos")
                brew install tree && print_success "tree installed via Homebrew" || print_warning "Failed to install tree via Homebrew"
            ;;
            *)
                if command_exists brew; then
                    brew install tree && print_success "tree installed via Homebrew" || print_warning "Failed to install tree via Homebrew"
                else
                    print_warning "Cannot install tree automatically on this system"
                fi
            ;;
        esac
    else
        print_info "Skipping tree, already installed"
    fi

    # Install diff-so-fancy (Git diff enhancement)
    if ! command_exists diff-so-fancy; then
        print_step "Installing diff-so-fancy..."
        if command_exists npm; then
            if npm install -g diff-so-fancy; then
                print_success "diff-so-fancy installed via npm"
            else
                print_warning "Failed to install diff-so-fancy via npm"
            fi
        else
            print_warning "npm not available - skipping diff-so-fancy installation"
        fi
    else
        print_info "Skipping diff-so-fancy, already installed"
    fi

    # Install PyEnv (Python Version Manager)
    if [[ ! -d "$HOME/.pyenv" ]]; then
        print_step "Installing PyEnv (Python Version Manager)..."
        if curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash; then
            print_success "PyEnv installed successfully"
            export PYENV_ROOT="$HOME/.pyenv"
            export PATH="$PYENV_ROOT/bin:$PATH"
            if command_exists pyenv; then
                eval "$(pyenv init --path)" 2>/dev/null || true
                eval "$(pyenv init -)" 2>/dev/null || true
                eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
                print_info "PyEnv initialized for current session"
                print_step "Installing latest stable Python version..."
                local latest_python
                latest_python=$(pyenv install --list 2>/dev/null | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
                if [[ -n "$latest_python" ]]; then
                    print_info "Installing Python $latest_python..."
                    if pyenv install "$latest_python"; then
                        pyenv global "$latest_python"
                        print_success "Python $latest_python installed and set as global default"
                        print_info "Python version: $(python --version 2>/dev/null || echo 'Available after shell restart')"
                    else
                        print_warning "Failed to install Python $latest_python"
                    fi
                else
                    print_warning "Could not determine latest Python version to install"
                fi
            fi
        else
            print_warning "Failed to install PyEnv"
        fi
    else
        print_info "Skipping PyEnv, already installed"
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        if command_exists pyenv; then
            eval "$(pyenv init --path)" 2>/dev/null || true
            eval "$(pyenv init -)" 2>/dev/null || true
            eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
            local current_python
            current_python=$(pyenv global 2>/dev/null)
            if [[ "$current_python" == "system" || -z "$current_python" ]]; then
                print_step "No Python version set in PyEnv, installing latest stable version..."
                local latest_python
                latest_python=$(pyenv install --list 2>/dev/null | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
                if [[ -n "$latest_python" ]]; then
                    print_info "Installing Python $latest_python..."
                    if pyenv install "$latest_python"; then
                        pyenv global "$latest_python"
                        print_success "Python $latest_python installed and set as global default"
                    else
                        print_warning "Failed to install Python $latest_python"
                    fi
                fi
            else
                print_info "PyEnv Python version: $current_python"
            fi
        fi
    fi

    # Install live-server (Development server)
    if command_exists npm && ! command_exists live-server; then
        print_step "Installing live-server (optional development server)..."
        if npm install -g live-server; then
            print_success "live-server installed successfully"
        else
            print_warning "Failed to install live-server - not critical"
        fi
    else
        if command_exists live-server; then
            print_info "Skipping live-server, already installed"
        else
            print_info "Skipping live-server (npm not available)"
        fi
    fi

    # Create ~/.local/bin if it doesn't exist
    if [[ -d "$HOME/.local/bin" ]]; then
        print_info "✅ ~/.local/bin directory exists"
    else
        print_step "Creating ~/.local/bin directory..."
        mkdir -p "$HOME/.local/bin"
        print_success "Created ~/.local/bin directory"
    fi

    print_step "Verifying development tools installation..."
    echo ""
    print_info "🛠️ Development tools status:"
    command_exists hub && echo "  ✓ hub $(hub --version | head -n1)" || echo "  ❌ hub (not available)"
    command_exists fzf && echo "  ✓ fzf $(fzf --version)" || echo "  ❌ fzf (not available)"
    command_exists fd && echo "  ✓ fd $(fd --version | head -n1)" || echo "  ○ fd (not available - fzf will use find)"
    command_exists bat && echo "  ✓ bat $(bat --version | head -n1)" || echo "  ○ bat (not available - fzf will use cat)"
    command_exists tree && echo "  ✓ tree $(tree --version | head -n1)" || echo "  ○ tree (not available - fzf will use ls)"
    command_exists diff-so-fancy && echo "  ✓ diff-so-fancy" || echo "  ❌ diff-so-fancy (not available)"
    if command_exists pyenv; then
        local pyenv_python
        pyenv_python=$(pyenv global 2>/dev/null)
        echo "  ✓ pyenv $(pyenv --version) (Python: ${pyenv_python:-system})"
    else
        echo "  ❌ pyenv (not available)"
    fi
    command_exists live-server && echo "  ✓ live-server" || echo "  ○ live-server (optional)"
    command_exists brew && echo "  ✓ brew $(brew --version | head -n1)" || echo "  ○ brew (not available on this system)"
    echo ""

    # Show fzf integration status
    if command_exists fzf; then
        echo -e "${CYAN}🔍 FZF Integration:${NC}"
        echo "  • Modern shell integration: $(fzf --zsh >/dev/null 2>&1 && echo '✅ Available (fzf --zsh)' || echo '⚠️ Fallback to manual scripts')"
        echo "  • File finder: $(command_exists fd && echo 'fd (fast)' || echo 'find (fallback)')"
        echo "  • File preview: $(command_exists bat && echo 'bat (syntax highlighted)' || echo 'cat (plain text)')"
        echo "  • Directory preview: $(command_exists tree && echo 'tree (structured)' || echo 'ls (simple)')"
        echo ""
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# 📁 DOTFILES CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

apply_dotfiles() {
    print_header "📁 APPLYING DOTFILES CONFIGURATION"
    local dotfiles_dir=""
    if is_remote_install; then
        print_info "Remote installation detected - downloading dotfiles..."
        dotfiles_dir=$(download_dotfiles)
        if [[ -z "$dotfiles_dir" ]]; then
            return 1
        fi
    else
        # Try multiple possible locations for dotfiles - all dynamic based on current user
        local possible_dirs=(
            "$SCRIPT_DIR"                           # Same directory as script
            "$HOME/projects/dotfiles"               # User projects/dotfiles
            "$HOME/dotfiles"                        # User dotfiles
            "$HOME/.dotfiles"                       # Hidden dotfiles directory
            "$HOME/dev/dotfiles"                    # Alternative dev location
            "$HOME/Development/dotfiles"            # Alternative Development location
            "$HOME/code/dotfiles"                   # Alternative code location
            "$HOME/src/dotfiles"                    # Alternative src location
        )

        print_info "Local installation detected - searching for dotfiles..."
        print_info "Current user: $(whoami), Home: $HOME"
        print_info "Script directory: $SCRIPT_DIR"

        for dir in "${possible_dirs[@]}"; do
            if [[ -f "$dir/.zshrc" ]]; then
                dotfiles_dir="$dir"
                print_info "Found dotfiles directory: $dotfiles_dir"
                break
            fi
        done

        if [[ -z "$dotfiles_dir" ]]; then
            # Last resort: check if we have any .zshrc file in common locations or current directory
            print_info "Performing extended search for .zshrc file..."
            local found_zshrc=""

            # Check if current directory has .zshrc
            if [[ -f "$PWD/.zshrc" ]]; then
                found_zshrc="$PWD"
            fi

            # If still not found, look for any .zshrc files in user's directory structure
            if [[ -z "$found_zshrc" ]]; then
                # Search in common development directories
                for base_dir in "$HOME" "$HOME/projects" "$HOME/dev" "$HOME/Development" "$HOME/code" "$HOME/src"; do
                    if [[ -d "$base_dir" ]]; then
                        # Look for dotfiles directories containing .zshrc
                        while IFS= read -r -d '' zshrc_file; do
                            local parent_dir
                            parent_dir=$(dirname "$zshrc_file")
                            if [[ -f "$zshrc_file" && -d "$parent_dir" ]]; then
                                found_zshrc="$parent_dir"
                                break 2
                            fi
                        done < <(find "$base_dir" -maxdepth 3 -name ".zshrc" -print0 2>/dev/null)
                    fi
                done
            fi

            if [[ -n "$found_zshrc" ]]; then
                dotfiles_dir="$found_zshrc"
                print_success "Found .zshrc in: $dotfiles_dir"
            else
                print_error "Cannot find .zshrc file anywhere."
                print_error "Searched the following directories:"
                for dir in "${possible_dirs[@]}"; do
                    if [[ -d "$dir" ]]; then
                        print_error "  ✓ $dir (exists, but no .zshrc found)"
                    else
                        print_error "  ✗ $dir (directory doesn't exist)"
                    fi
                done
                print_error ""
                print_error "Current working directory: $PWD"
                print_error "Files in current directory:"
                ls -la "$PWD" | head -10 | while read -r line; do
                    print_error "    $line"
                done
                print_error ""
                print_error "To fix this issue, either:"
                print_error "1. Run this script from a directory that contains .zshrc"
                print_error "2. Place your .zshrc file in one of the expected locations above"
                print_error "3. Create a .zshrc file in the script directory: $SCRIPT_DIR"
                print_error "4. Or run the script remotely to download the dotfiles automatically"
                return 1
            fi
        fi
    fi
    print_step "Applying configuration from $dotfiles_dir..."

    # Handle .zshrc - check if it's already the same file or symlinked
    if [[ -L "$HOME/.zshrc" ]]; then
        local link_target
        link_target=$(readlink "$HOME/.zshrc")
        if [[ "$link_target" == "$dotfiles_dir/.zshrc" ]] || [[ "$(realpath "$link_target")" == "$(realpath "$dotfiles_dir/.zshrc")" ]]; then
            print_info ".zshrc is already symlinked to dotfiles directory"
            print_success "✅ .zshrc configuration already applied"
        else
            print_step "Updating .zshrc symlink..."
            ln -sf "$dotfiles_dir/.zshrc" "$HOME/.zshrc"
            print_success "Updated .zshrc symlink"
        fi
        elif [[ -f "$HOME/.zshrc" ]] && cmp -s "$dotfiles_dir/.zshrc" "$HOME/.zshrc"; then
        print_info ".zshrc files are identical - no update needed"
        print_success "✅ .zshrc configuration already applied"
        elif cp "$dotfiles_dir/.zshrc" "$HOME/.zshrc" 2>/dev/null; then
        print_success "Applied .zshrc configuration"
    else
        print_warning "Could not copy .zshrc, but continuing..."
    fi
    local dotfiles=(".gitconfig" ".vimrc" ".tmux.conf")
    for dotfile in "${dotfiles[@]}"; do
        if [[ -f "$dotfiles_dir/$dotfile" ]]; then
            if [[ -L "$HOME/$dotfile" ]]; then
                local link_target
                link_target=$(readlink "$HOME/$dotfile")
                if [[ "$link_target" == "$dotfiles_dir/$dotfile" ]] || [[ "$(realpath "$link_target")" == "$(realpath "$dotfiles_dir/$dotfile")" ]]; then
                    print_info "$dotfile is already symlinked to dotfiles directory"
                else
                    ln -sf "$dotfiles_dir/$dotfile" "$HOME/$dotfile"
                    print_success "Updated $dotfile symlink"
                fi
                elif [[ -f "$HOME/$dotfile" ]] && cmp -s "$dotfiles_dir/$dotfile" "$HOME/$dotfile"; then
                print_info "$dotfile files are identical - no update needed"
                elif cp "$dotfiles_dir/$dotfile" "$HOME/$dotfile" 2>/dev/null; then
                print_success "Applied $dotfile"
            else
                print_warning "Failed to copy $dotfile - may already be the same file"
            fi
        fi
    done
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
    echo -e "   • Zsh plugins (autosuggestions, syntax highlighting, z, you-should-use)"
    echo -e "   • NVM and Node.js LTS"
    echo -e "   • Package managers (ni, pnpm)"
    echo -e "   • GitHub CLI (gh)"
    echo -e "   • Modern fzf with shell integration (CTRL-T, CTRL-R, ALT-C)"
    echo -e "   • Enhanced fzf tools (fd, bat, tree)"
    echo -e "   • Development tools (hub, diff-so-fancy, pyenv, live-server)"
    echo -e "   • Custom .zshrc configuration"
    echo ""
    if [[ -d "$BACKUP_DIR" ]]; then
        echo -e "${CYAN}💾 Backups saved to:${NC} $BACKUP_DIR"
        echo ""
    fi
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "   1. ${WHITE}Restart your terminal${NC} or run: ${CYAN}exec zsh${NC}"
    echo -e "   2. Verify everything works: ${CYAN}help${NC}"
    echo -e "   3. Try fzf key bindings:"
    echo -e "      • ${CYAN}CTRL-T${NC} - Fuzzy find files/directories"
    echo -e "      • ${CYAN}CTRL-R${NC} - Fuzzy search command history"
    echo -e "      • ${CYAN}ALT-C${NC}  - Fuzzy change directory"
    echo -e "   4. Install additional tools as needed"
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
    install_development_tools
    apply_dotfiles
    configure_shell
    display_summary
    log "Installation completed successfully"
}

main "$@"
