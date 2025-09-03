#!/usr/bin/env zsh
# shellcheck shell=bash disable=SC1071,SC2034,SC1091,SC2164,SC2155,SC2119,SC2120,SC2086,SC2207
# Note: This is a zsh config file. Some zsh-specific syntax may not be fully compatible with shellcheck.
# Many "issues" reported by shellcheck are normal zsh patterns and don't need fixing.
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                   ZSH CONFIG                                 ║
# ║                          Tom's Development Environment                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ────────────────────────────────────────────────────────────────────────────────
# 🎨 SHELL CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

# Oh My Zsh setup
export ZSH="$HOME/.oh-my-zsh"

# Pure prompt setup (preferred over Spaceship)
fpath+=("$HOME/.zsh/pure")
autoload -U promptinit; promptinit
prompt pure

# Zsh plugins configuration
# Install commands (run these if plugins are missing):
# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
# git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# git clone https://github.com/agkozak/zsh-z $ZSH_CUSTOM/plugins/zsh-z
# git clone https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
plugins=(
  git                    # Git aliases and functions
  zsh-autosuggestions   # Fish-like autosuggestions
  zsh-syntax-highlighting # Syntax highlighting
  zsh-z                 # Directory jumping
  you-should-use        # Alias usage reminders
)

# Load Oh My Zsh
# shellcheck disable=SC1091
source "$ZSH/oh-my-zsh.sh"

# ────────────────────────────────────────────────────────────────────────────────
# 🌍 ENVIRONMENT SETUP
# ────────────────────────────────────────────────────────────────────────────────

# Node Version Manager (NVM)
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ────────────────────────────────────────────────────────────────────────────────
# 📦 NODE.JS & PACKAGE MANAGEMENT
# ────────────────────────────────────────────────────────────────────────────────
# Using 'ni' for universal package manager commands
# Install: npm i -g @antfu/ni
# Documentation: https://github.com/antfu/ni

# Package manager aliases
alias nio="ni --prefer-offline"        # Install with offline preference
alias s="nr start"                     # Start development server
alias b="nr build"                     # Build project
alias bw="nr build --watch"            # Build with watch mode
alias t="nr test"                      # Run tests
alias tu="nr test -u"                  # Update test snapshots
alias tw="nr test --watch"             # Run tests in watch mode
alias w="nr watch"                     # Watch mode
alias p="nr play"                      # Playground mode
alias c="nr typecheck"                 # Type checking
alias lint="nr lint"                   # Lint code
alias lintf="nr lint --fix"            # Lint and fix
alias re="nr release"                  # Create release

# ────────────────────────────────────────────────────────────────────────────────
# 🔧 GIT CONFIGURATION & ALIASES
# ────────────────────────────────────────────────────────────────────────────────

# Use GitHub CLI as git wrapper
alias git=hub

# Basic Git Operations
alias gs='git status'                  # Git status
alias gp='git push'                    # Git push
alias gpf='git push --force'           # Force push
alias gpft='git push --follow-tags'    # Push with tags
alias gpl='git pull --rebase'          # Pull with rebase
alias gcl='git clone'                  # Clone repository
alias grt='cd "$(git rev-parse --show-toplevel)"'  # Go to repository root

# Staging & Committing
alias ga='git add'                     # Add files
alias gA='git add -A'                  # Add all files
alias gc='git commit'                  # Commit
alias gcm='git commit -m'              # Commit with message
alias gca='git commit -a'              # Commit all
alias gcam='git add -A && git commit -m'  # Add all and commit

# Branching & Checkout
alias gco='git checkout'               # Checkout
alias gcob='git checkout -b'           # Create and checkout branch
alias gb='git branch'                  # List branches
alias gbd='git branch -d'              # Delete branch

# Smart branch switching function
function switch() {
  case "$1" in
    m|main) git checkout main 2>/dev/null || git checkout master ;;
    d|dev|develop) git checkout develop 2>/dev/null || git checkout development ;;
    s|stage|staging) git checkout staging ;;
    *) git checkout "$1" ;;
  esac
}

# Keep convenience aliases
alias main='switch main'               # Switch to main/master
alias master='switch main'             # Switch to main/master (unified)

# Stashing & History
alias gst='git stash'                  # Stash changes
alias gl='git log'                     # Git log
alias glo='git log --oneline --graph'  # Pretty log
alias grh='git reset HEAD'             # Reset to HEAD
alias grh1='git reset HEAD~1'          # Reset one commit

# Rebasing & Advanced
alias grb='git rebase'                 # Rebase
alias grbom='git rebase origin/master' # Rebase on origin/master
alias grbc='git rebase --continue'     # Continue rebase
alias gfrb='git fetch origin && git rebase origin/master'  # Fetch and rebase

# Cleaning & Utilities
alias gxn='git clean -dn'              # Dry run clean
alias gx='git clean -df'               # Force clean
alias grm='git rm'                     # Remove files
alias gmv='git mv'                     # Move files
alias gsha='git rev-parse HEAD | pbcopy'  # Copy commit SHA
alias ghci='gh run list -L 1'          # Latest CI run

# ────────────────────────────────────────────────────────────────────────────────
# 📁 PROJECT-SPECIFIC SHORTCUTS
# ────────────────────────────────────────────────────────────────────────────────

# SpendCloud Project Navigation
alias sc='cd ~/development/spend-cloud'           # Go to SpendCloud
alias scapi='sc && cd api'                        # Go to API folder
alias scui='sc && cd ui'                          # Go to UI folder
alias cui='code ~/development/spend-cloud/ui'     # Open UI in VSCode
alias capi='code ~/development/spend-cloud/api'   # Open API in VSCode
alias devapi='scapi && sct dev'                   # Start API development

# Proactive Frame Project
alias pf='cd ~/development/proactive-frame'       # Go to Proactive Frame
alias cpf='code ~/development/proactive-frame'    # Open in VSCode

# ────────────────────────────────────────────────────────────────────────────────
# 🚀 DEVELOPMENT FUNCTIONS
# ────────────────────────────────────────────────────────────────────────────────

# SpendCloud Cluster Management
# Starts the development cluster with all services
function cluster() {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local PURPLE='\033[0;35m'
  local CYAN='\033[0;36m'
  local WHITE='\033[1;37m'
  local NC='\033[0m'

  # Store the original directory
  local original_dir
  original_dir=$(pwd)

  # Handle stop command
  if [[ "$1" == "stop" ]]; then
    echo -e "${YELLOW}🛑 Stopping all cluster services...${NC}"

    # Stop and remove development containers first
    echo -e "${CYAN}🔍 Stopping and removing all containers...${NC}"
    local dev_containers
    dev_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)")
    if [[ -n "$dev_containers" ]]; then
      echo "$dev_containers" | xargs -r docker stop 2>/dev/null || true
      echo "$dev_containers" | xargs -r docker rm 2>/dev/null || true
      echo -e "${GREEN}✅ Containers stopped and removed${NC}"
    fi

    # Stop SCT cluster
    echo -e "${BLUE}🛑 Stopping SCT cluster...${NC}"
    sct cluster stop
    echo -e "${GREEN}✅ Cluster stopped successfully${NC}"
    return 0
  fi

  # Handle logs command
  if [[ "$1" == "logs" ]]; then
    if [[ -n "$2" ]]; then
      echo -e "${CYAN}📋 Showing logs for service: $2${NC}"
      sct cluster logs "$2"
    else
      echo -e "${CYAN}📋 Showing logs for all cluster services...${NC}"
      sct cluster logs
    fi
    return 0
  fi

  # Handle help command
  if [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
    echo -e "${GREEN}🏢 SpendCloud Cluster Management${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  cluster                    # Start cluster and development services"
    echo -e "  cluster --rebuild          # Rebuild and start cluster with fresh images"
    echo -e "  cluster stop              # Stop all cluster and development services"
    echo -e "  cluster logs [service]    # Show logs for all services or specific service"
    echo -e "  cluster help              # Show this help message"
    echo ""
    echo -e "${BLUE}💡 Automatically manages development containers and SCT cluster${NC}"
    return 0
  fi

  # Check for and stop development containers (for start/rebuild commands)
  echo -e "${CYAN}🔍 Checking for existing containers...${NC}"
  local dev_containers
  dev_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)" | head -15)

  if [[ -n "$dev_containers" ]]; then
    echo -e "${YELLOW}⚠️  Found existing containers that may conflict:${NC}"
    echo "$dev_containers" | while read -r container; do
      echo -e "  • $container"
    done
    echo -e "${YELLOW}🛑 Stopping and removing containers before cluster operation...${NC}"
    echo "$dev_containers" | xargs -r docker stop 2>/dev/null || true
    echo "$dev_containers" | xargs -r docker rm 2>/dev/null || true
    echo -e "${GREEN}✅ Containers stopped and removed${NC}"
  else
    echo -e "${GREEN}✅ No conflicting containers found${NC}"
  fi

  if [[ "$1" == "--rebuild" ]]; then
    echo -e "${YELLOW}🔄 Rebuilding cluster with fresh images...${NC}"
    echo -e "${BLUE}🚀 Starting SCT cluster...${NC}"
    if ! sct cluster start --build --pull; then
      echo -e "${RED}❌ Failed to start SCT cluster. Aborting...${NC}"
      return 1
    fi
  else
    echo -e "${BLUE}🚀 Starting SCT cluster...${NC}"
    if ! sct cluster start; then
      echo -e "${RED}❌ Failed to start SCT cluster. Aborting...${NC}"
      return 1
    fi
  fi

  sleep 2

  echo -e "${PURPLE}⚡ Starting dev for spend-cloud/api...${NC}"
  cd ~/development/spend-cloud/api || return
  sct dev > /dev/null 2>&1 &

  echo -e "${CYAN}⚡ Starting dev for spend-cloud/proactive-frame...${NC}"
  cd ~/development/proactive-frame || return
  sct dev > /dev/null 2>&1 &

  # Return to the original directory
  cd "$original_dir" || return

  echo -e "${GREEN}✅ All services started!${NC}"
  echo -e "${WHITE}🌟 SCT cluster is running and dev services are running in the background.${NC}"
}

# Database Migration Management
# Run Laravel migrations in the SpendCloud API container
function migrate() {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local NC='\033[0m'

  # Try multiple container name patterns
  local container_names=("api-spend-cloud-api" "spend-cloud-api" "api_spend-cloud-api" "spend_cloud_api")
  local found_container=""

  # Find the running container
  for container_name in "${container_names[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
      found_container="$container_name"
      break
    fi
  done

  # If no exact match, try finding any container with "spend-cloud" and "api" in the name
  if [[ -z "$found_container" ]]; then
    found_container=$(docker ps --format "{{.Names}}" | grep -i "spend.*cloud.*api\|api.*spend.*cloud" | head -1)
  fi

  # If still no container found, show available containers for debugging
  if [[ -z "$found_container" ]]; then
    echo -e "${RED}❌ SpendCloud API container not found${NC}"
    echo -e "${CYAN}🔍 Available running containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}" | head -10
    echo -e "${YELLOW}💡 Start the development environment first with 'cluster' or 'sct dev'${NC}"
    return 1
  fi

  echo -e "${CYAN}🐳 Using container: ${found_container}${NC}"

  # Default to all groups if no arguments provided
  if [[ $# -eq 0 ]]; then
    echo -e "${BLUE}🗄️  Running migrations for all databases...${NC}"
    docker exec -it "$found_container" php artisan migrate-all --groups=customers,proactive_config,proactive-default,sharedStorage
  else
    case "$1" in
      "all")
        echo -e "${BLUE}🗄️  Running migrations for all databases...${NC}"
        docker exec -it "$found_container" php artisan migrate-all --groups=customers,proactive_config,proactive-default,sharedStorage
        ;;
      "customers")
        echo -e "${BLUE}🗄️  Running customer database migrations...${NC}"
        docker exec -it "$found_container" php artisan migrate --path=database/migrations/customers
        ;;
      "config")
        echo -e "${BLUE}🗄️  Running config database migrations...${NC}"
        docker exec -it "$found_container" php artisan migrate --path=database/migrations/config
        ;;
      "shared"|"sharedstorage")
        echo -e "${BLUE}🗄️  Running shared storage migrations...${NC}"
        docker exec -it "$found_container" php artisan migrate --path=database/migrations/sharedStorage
        ;;
      "rollback")
        if [[ -z "$2" ]]; then
          echo -e "${YELLOW}⚠️  Rolling back last customer migration batch...${NC}"
          docker exec -it "$found_container" php artisan migrate:rollback --path=database/migrations/customers
        else
          case "$2" in
            "customers")
              echo -e "${YELLOW}⚠️  Rolling back customer database migrations...${NC}"
              docker exec -it "$found_container" php artisan migrate:rollback --path=database/migrations/customers
              ;;
            "config")
              echo -e "${YELLOW}⚠️  Rolling back config database migrations...${NC}"
              docker exec -it "$found_container" php artisan migrate:rollback --path=database/migrations/config
              ;;
            "shared"|"sharedstorage")
              echo -e "${YELLOW}⚠️  Rolling back shared storage migrations...${NC}"
              docker exec -it "$found_container" php artisan migrate:rollback --path=database/migrations/sharedStorage
              ;;
            *)
              echo -e "${RED}❌ Invalid rollback target. Use: customers, config, shared${NC}"
              return 1
              ;;
          esac
        fi
        ;;
      "help"|"-h"|"--help")
        echo -e "${GREEN}🗄️  Database Migration Commands${NC}"
        echo ""
        echo -e "${YELLOW}Usage:${NC}"
        echo -e "  migrate                    # Run all migrations"
        echo -e "  migrate all               # Run all migrations"
        echo -e "  migrate customers         # Run customer database migrations"
        echo -e "  migrate config            # Run config database migrations"
        echo -e "  migrate shared            # Run shared storage migrations"
        echo -e "  migrate rollback          # Rollback last customer migration"
        echo -e "  migrate rollback customers # Rollback customer migrations"
        echo -e "  migrate rollback config   # Rollback config migrations"
        echo -e "  migrate rollback shared   # Rollback shared storage migrations"
        echo ""
        echo -e "${BLUE}💡 Auto-detects running SpendCloud API container${NC}"
        return 0
        ;;
      *)
        echo -e "${RED}❌ Invalid option: $1${NC}"
        echo -e "${YELLOW}💡 Use 'migrate help' to see available commands${NC}"
        return 1
        ;;
    esac
  fi

  local migration_exit_code=$?
  if [[ $migration_exit_code -eq 0 ]]; then
    echo -e "${GREEN}✅ Migration completed successfully${NC}"
  else
    echo -e "${RED}❌ Migration failed${NC}"
    return 1
  fi
}

# Git utility functions
function glp() {
  git --no-pager log -"$1"
}

function gd() {
  if [[ -z $1 ]]; then
    git diff --color | diff-so-fancy
  else
    git diff --color "$1" | diff-so-fancy
  fi
}

function gdc() {
  if [[ -z $1 ]]; then
    git diff --color --cached | diff-so-fancy
  else
    git diff --color --cached "$1" | diff-so-fancy
  fi
}

# Pull Request management
function pr() {
  if [[ "$1" == "ls" ]]; then
    gh pr list
  else
    gh pr checkout $1
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# 📂 DIRECTORY NAVIGATION & MANAGEMENT
# ────────────────────────────────────────────────────────────────────────────────
# Directory structure:
# ~/development  - Main projects
# ~/forks       - Forked repositories
# ~/repros      - Bug reproductions
# ~/projects    - Personal projects

# Directory navigation functions
# Enhanced directory navigation with fuzzy finding
function nav() {
  local base_dir
  case "$1" in
    d|dev|development) base_dir="$HOME/development" ;;
    r|repros) base_dir="$HOME/repros" ;;
    f|forks) base_dir="$HOME/forks" ;;
    p|projects) base_dir="$HOME/projects" ;;
    *) echo "Usage: nav {d|r|f|p} [directory]" && return 1 ;;
  esac

  if [[ -n "$2" ]]; then
    cd "$base_dir/$2"
  else
    cd "$base_dir"
  fi
}

# Keep original functions for backward compatibility
function d() { nav d "$1"; }
function repros() { nav r "$1"; }
function forks() { nav f "$1"; }
function projects() { nav p "$1"; }

# Create directory and cd into it
function dir() {
  mkdir -p "$1" && cd "$1"
}

# ────────────────────────────────────────────────────────────────────────────────
# 🌐 REPOSITORY CLONING & CODE MANAGEMENT
# ────────────────────────────────────────────────────────────────────────────────

# Enhanced clone function
function clone() {
  if [[ -z $2 ]]; then
    hub clone "$@" && cd "$(basename "$1" .git)"
  else
    hub clone "$@" && cd "$2"
  fi
}

# Unified clone function with directory targeting
function clone_to() {
  local target_dir="$1"
  shift
  case "$target_dir" in
    d|dev|development) d && clone "$@" && code . && cd ~2 ;;
    r|repros) repros && clone "$@" && code . && cd ~2 ;;
    f|forks) forks && clone "$@" && code . && cd ~2 ;;
    p|projects) projects && clone "$@" && code . && cd ~2 ;;
    *) echo "Usage: clone_to {d|r|f|p} <repo>" && return 1 ;;
  esac
}

# Convenience aliases for the old functions
alias cloned='clone_to d'
alias cloner='clone_to r'
alias clonef='clone_to f'
alias clonep='clone_to p'

function coded() {   # Open project in VSCode from ~/development
  d && code "$@" && cd -
}

# Development server
function serve() {
  if [[ -z $1 ]]; then
    live-server dist
  else
    live-server $1
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# 🔍 PROJECT DISCOVERY & SWITCHING
# ────────────────────────────────────────────────────────────────────────────────

# Fuzzy find and switch to any project
function proj() {
  local selected
  selected=$(find ~/development ~/forks ~/repros ~/projects -maxdepth 2 -type d -name ".git" 2>/dev/null |
            sed 's|/.git||' |
            sed "s|$HOME/||" |
            sort |
            fzf --height=40% --layout=reverse --border --prompt="📁 Project: ")

  if [[ -n $selected ]]; then
    cd "$HOME/$selected"
    echo "📂 Switched to: $(pwd)"
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# 🤖 SMART COMMIT FUNCTION
# ────────────────────────────────────────────────────────────────────────────────

# Smart commit with auto-generated messages based on file changes
function commit() {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local NC='\033[0m'

  # Verify git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    return 1
  fi

  # Stage all changes if nothing is staged
  if git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️  No staged changes. Staging all changes...${NC}"
    git add -A
    if git diff --cached --quiet; then
      echo -e "${RED}❌ No changes to commit${NC}"
      return 1
    fi
  fi

  # Use provided message if given
  if [[ -n "$1" ]]; then
    git commit -m "$*"
    return $?
  fi

  # Analyze changes for smart message generation
  local files_changed=$(git diff --cached --name-only | head -5)
  local files_count=$(git diff --cached --name-only | wc -l)
  local additions=$(git diff --cached --numstat | awk '{add+=$1} END {print add+0}')
  local deletions=$(git diff --cached --numstat | awk '{del+=$2} END {print del+0}')
  local commit_msg=""

  # Pattern-based message generation
  if echo "$files_changed" | grep -q "package\.json\|yarn\.lock\|package-lock\.json\|pnpm-lock\.yaml"; then
    commit_msg="📦 Update dependencies"
  elif echo "$files_changed" | grep -q "\.md$"; then
    commit_msg="📝 Update documentation"
  elif echo "$files_changed" | grep -q "test\|spec"; then
    commit_msg="🧪 Update tests"
  elif echo "$files_changed" | grep -q "\.css\|\.scss\|\.sass\|\.less"; then
    commit_msg="💄 Update styles"
  elif echo "$files_changed" | grep -q "config\|\.env\|\.config\."; then
    commit_msg="🔧 Update configuration"
  elif [[ $additions -gt 50 && $deletions -lt 10 ]]; then
    commit_msg="✨ Add new features"
  elif [[ $deletions -gt 20 && $additions -lt 10 ]]; then
    commit_msg="🔥 Remove code"
  elif [[ $files_count -eq 1 ]]; then
    local filename=$(basename "$files_changed")
    commit_msg="🔨 Update $filename"
  else
    commit_msg="🚀 Update codebase"
  fi

  # Add file count for multiple files
  if [[ $files_count -gt 1 ]]; then
    commit_msg="$commit_msg ($files_count files)"
  fi

  echo -e "${BLUE}📋 Proposed commit message:${NC} $commit_msg"
  echo -e "${YELLOW}Press Enter to use this message, or type a custom one:${NC}"
  read -r custom_msg

  if [[ -n "$custom_msg" ]]; then
    commit_msg="$custom_msg"
  fi

  git commit -m "$commit_msg"
  echo -e "${GREEN}✅ Committed with message: $commit_msg${NC}"
}

# ────────────────────────────────────────────────────────────────────────────────
# ⚙️  SYSTEM ENVIRONMENT SETUP
# ────────────────────────────────────────────────────────────────────────────────

# Homebrew (Linux)
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Google Cloud SDK
if [ -f '/home/tom/google-cloud-sdk/path.zsh.inc' ]; then
  . '/home/tom/google-cloud-sdk/path.zsh.inc'
fi
if [ -f '/home/tom/google-cloud-sdk/completion.zsh.inc' ]; then
  . '/home/tom/google-cloud-sdk/completion.zsh.inc'
fi

# SpendCloud-specific paths (auto-generated)
## <SPEND_CLOUD_GCLOUD_BINARY_PATH>
## Written on 16-01-2025 at 10:22:04
export PATH="${PATH}:/home/tom/google-cloud-sdk/bin"
## </SPEND_CLOUD_GCLOUD_BINARY_PATH>

## <SPEND_CLOUD_PATHS>
## Written on 16-01-2025 at 10:22:08
export PATH="$PATH:$HOME/.composer/vendor/bin"
export PATH="$PATH:$(yarn global bin)"
export PATH="$PATH:$HOME/.local/bin"
## </SPEND_CLOUD_PATHS>

# PNPM package manager
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# PNPM alias for shorter commands
alias pn=pnpm

# Python environment management (pyenv)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# ASDF version manager
## <SPEND_CLOUD_ASDF>
## Written on 02-06-2025 at 16:51:11
. /home/tom/.asdf/asdf.sh
## </SPEND_CLOUD_ASDF>

# ────────────────────────────────────────────────────────────────────────────────
# 📖 INTERACTIVE HELP SYSTEM
# ────────────────────────────────────────────────────────────────────────────────

function help() {
  local GRAY='\033[0;90m'
  local GREEN='\033[0;32m'
  local YELLOW_BOLD='\033[1;33m'
  local BLUE='\033[0;34m'
  local PURPLE='\033[0;35m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  # Inline categories data (format: key,emoji,title,description)
  local categories_data="key,emoji,title,description
git,🔧,Git,Git version control commands and utilities for daily development workflow
node,📦,Node.js,Package management and Node.js development using universal package manager 'ni'
nav,📁,Navigation,Directory navigation and file management across project directories
dev,🚀,Development,Development workflow utilities and project management tools
spendcloud,🏢,SpendCloud,Project-specific shortcuts and utilities for SpendCloud development
proframe,🖼️,Proactive Frame,Project shortcuts for Proactive Frame development
flow,🌊,Flow,Ultimate workflow automation for complete development lifecycle
util,🛠️,Utilities,General purpose utilities and helper functions"

  # Inline commands data (format: category,command,brief,verbose,alias_type,safety_level,example)
  local commands_data="category,command,brief,verbose,alias_type,safety_level,example
git,gs,status,Show working tree status with staged and unstaged changes,alias,safe,gs
git,gp,push,Push commits to remote repository,alias,caution,gp
git,gpf,force push,Force push commits (overwrites remote history),alias,dangerous,gpf
git,gpft,push tags,Push commits along with associated tags,alias,caution,gpft
git,gpl,pull rebase,Pull remote changes and rebase local commits on top,alias,safe,gpl
git,gcl,clone,Clone a repository from remote URL,alias,safe,gcl https://github.com/user/repo
git,grt,to repo root,Navigate to the root directory of current git repository,alias,safe,grt
git,ga,add,Stage files for the next commit,alias,safe,ga file.txt
git,gA,add all,Stage all changes (modified new and deleted files),alias,safe,gA
git,gc,commit,Create a new commit with staged changes,alias,safe,gc
git,gcm,commit with msg,Create a commit with inline message,alias,safe,gcm \"Fix bug\"
git,gca,commit all,Commit all tracked file changes (skip staging),alias,safe,gca
git,gcam,add all & commit,Stage all changes and commit with message,alias,safe,gcam \"Update feature\"
git,gco,checkout,Switch branches or restore files,alias,caution,gco branch-name
git,gcob,create branch,Create and checkout new branch in one command,alias,safe,gcob feature/new-feature
git,gb,list branches,List all local branches with current branch highlighted,alias,safe,gb
git,gbd,delete branch,Delete specified branch (safe delete with merge check),alias,caution,gbd old-branch
git,switch,smart switch,Intelligent branch switching with shortcuts (m=main d=dev s=staging),function,safe,switch main
git,main,to main,Switch to main or master branch automatically,alias,safe,main
git,master,to master,Switch to main or master branch (unified with main),alias,safe,master
git,gst,stash,Stash current changes for temporary storage,alias,safe,gst
git,gl,log,Show commit history with full details,alias,safe,gl
git,glo,pretty log,Show compact commit history with branch visualization,alias,safe,glo
git,grh,reset head,Unstage all staged changes without losing modifications,alias,caution,grh
git,grh1,reset 1 commit,Reset to previous commit keeping changes in working directory,alias,dangerous,grh1
git,grb,rebase,Rebase current branch onto another branch,alias,caution,grb main
git,grbom,rebase origin,Rebase current branch onto remote master,alias,caution,grbom
git,grbc,continue rebase,Continue rebase after resolving conflicts,alias,caution,grbc
git,gfrb,fetch & rebase,Fetch remote changes and rebase current branch,alias,caution,gfrb
git,gxn,clean preview,Preview untracked files that would be removed (dry run),alias,safe,gxn
git,gx,clean force,Remove untracked files and directories,alias,dangerous,gx
git,grm,remove files,Remove files from git tracking and working directory,alias,caution,grm file.txt
git,gmv,move files,Move or rename files while preserving git history,alias,safe,gmv old.txt new.txt
git,gsha,copy sha,Copy current commit SHA to clipboard for sharing,alias,safe,gsha
git,ghci,ci status,Display status of most recent CI/CD pipeline run,alias,safe,ghci
git,commit,smart commit,Intelligent commit with auto-generated messages based on changes,function,safe,commit \"optional message\"
git,gd,diff pretty,Show changes with enhanced formatting and colors,function,safe,gd filename
git,gdc,diff cached,Show staged changes with enhanced formatting,function,safe,gdc
git,glp,log last n,Show last n commits in compact format,function,safe,glp 5
git,pr,pull requests,Manage pull requests with GitHub CLI,function,safe,pr ls
node,ni,install,Install dependencies with auto-detected package manager,alias,safe,ni
node,nio,install offline,Install packages with offline preference for faster installs,alias,safe,nio
node,s,start,Start development server using universal package manager,alias,safe,s
node,b,build,Build project using configured build script,alias,safe,b
node,bw,build watch,Build project with file watching for automatic rebuilds,alias,safe,bw
node,t,test,Run test suite using configured test script,alias,safe,t
node,tu,test update,Update test snapshots for Jest or similar frameworks,alias,safe,tu
node,tw,test watch,Run tests in watch mode for continuous testing,alias,safe,tw
node,w,watch,Start watch mode for automatic rebuilds on file changes,alias,safe,w
node,p,play,Start playground mode for development experimentation,alias,safe,p
node,c,typecheck,Run TypeScript type checking without compilation,alias,safe,c
node,lint,lint,Run code linting to check for style and syntax issues,alias,safe,lint
node,lintf,lint fix,Run linting with automatic fixing of correctable issues,alias,safe,lintf
node,re,release,Create a new release using configured release script,alias,caution,re
spendcloud,sc,to spendcloud,Navigate to main SpendCloud project directory,alias,safe,sc
spendcloud,scapi,to sc api,Navigate to SpendCloud API subdirectory,alias,safe,scapi
spendcloud,scui,to sc ui,Navigate to SpendCloud UI subdirectory,alias,safe,scui
spendcloud,cui,code ui,Open SpendCloud UI in VSCode editor,alias,safe,cui
spendcloud,capi,code api,Open SpendCloud API in VSCode editor,alias,safe,capi
spendcloud,devapi,dev api,Navigate to API and start development server,alias,safe,devapi
spendcloud,migrate,run migrations,Run Laravel database migrations in Docker container with automatic checks,function,safe,migrate customers
proframe,pf,to proframe,Navigate to Proactive Frame project directory,alias,safe,pf
proframe,cpf,code proframe,Open Proactive Frame project in VSCode editor,alias,safe,cpf
nav,nav,unified nav,Universal navigation with shortcuts (d=dev r=repros f=forks p=projects),function,safe,nav d project-name
nav,d,to development,Navigate to development projects directory,function,safe,d project-name
nav,repros,to repros,Navigate to bug reproduction projects directory,function,safe,repros
nav,forks,to forks,Navigate to forked repositories directory,function,safe,forks
nav,projects,to projects,Navigate to personal projects directory,function,safe,projects
nav,dir,make & cd,Create directory and navigate into it in one command,function,safe,dir new-folder
nav,proj,fuzzy project,Fuzzy find and switch to any project across all directories,function,safe,proj
dev,cluster,start cluster,Start complete development cluster with all services,function,safe,cluster --rebuild
dev,clone,clone & cd,Enhanced clone that automatically navigates into cloned repository,function,safe,clone user/repo
dev,clone_to,clone to dir,Clone repository to specific directory with shortcuts,function,safe,clone_to d user/repo
dev,cloned,clone to dev,Clone to development directory and open in VSCode,function,safe,cloned user/repo
dev,cloner,clone to repros,Clone to repros directory and open in VSCode,function,safe,cloner user/repo
dev,clonef,clone to forks,Clone to forks directory and open in VSCode,function,safe,clonef user/repo
dev,clonep,clone to projects,Clone to projects directory and open in VSCode,function,safe,clonep user/repo
dev,coded,code from dev,Navigate to development directory and open project in VSCode,function,safe,coded project-name
dev,serve,dev server,Start live development server with automatic reloading,function,safe,serve dist
flow,flow fresh,fresh start,Complete fresh development start with intelligent dependency cleanup,function,caution,flow fresh
flow,flow ditch,discard all,Discard all changes (staged + unstaged + untracked files),function,dangerous,flow ditch
flow,flow save,stash changes,Stash all changes with automatic or custom message,function,safe,flow save \"message\"
flow,flow ship,ship workflow,Complete shipping workflow with linting tests and deployment,function,caution,flow ship \"message\"
flow,flow sync,sync branch,Sync with remote branch using rebase with automatic stashing,function,caution,flow sync
flow,flow feature,new feature,Create feature branch from latest main with proper naming,function,safe,flow feature user-auth
flow,flow hotfix,new hotfix,Create hotfix branch from latest main for urgent fixes,function,safe,flow hotfix critical-bug
flow,flow cleanup,cleanup workspace,Remove merged branches and clean build artifacts,function,caution,flow cleanup
util,help,help system,Display command help in compact verbose or detailed format,function,safe,help -v
util,help_add,add command,Add new command to help system database,function,safe,help_add git gco \"checkout\" \"Switch branches\"
util,help_add_category,add category,Add new category to help system database,function,safe,help_add_category key 🎯 Title Description"

  # Helper function to parse inline CSV and get category info
  _get_category_info() {
    local key="$1"
    local field="$2"  # emoji, title, or description

    # Skip header line and find matching category
    echo "$categories_data" | tail -n +2 | while IFS=',' read -r csv_key emoji title description; do
      if [[ "$csv_key" == "$key" ]]; then
        case "$field" in
          "emoji") echo "$emoji" ;;
          "title") echo "$title" ;;
          "description") echo "$description" ;;
        esac
        break
      fi
    done
  }

  # Helper function to get commands for a category
  _get_category_commands() {
    local category="$1"

    # Skip header line and filter by category, return command:description pairs
    echo "$commands_data" | tail -n +2 | while IFS=',' read -r cat cmd brief verbose alias_type safety_level example; do
      if [[ "$cat" == "$category" ]]; then
        echo "$cmd:$verbose"
      fi
    done
  }

  # Helper function to print command with proper formatting
  _print_command() {
    local cmd="$1"
    local desc="$2"
    local max_width=15

    # Calculate padding for alignment
    local cmd_length=${#cmd}
    local padding=$((max_width - cmd_length))
    local spaces=""
    for ((i=0; i<padding; i++)); do
      spaces+=" "
    done

    echo -e "${spaces}${YELLOW_BOLD}${cmd}${NC}   ${desc}"
  }

  # Get list of all categories from inline data
  local categories=($(echo "$categories_data" | tail -n +2 | cut -d',' -f1))

  # Enhanced details mode
  if [[ "$1" == "--details" || "$1" == "-d" ]]; then
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║            📚 Command Reference with Safety & Examples           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""

    for category in "${categories[@]}"; do
      local emoji=$(_get_category_info "$category" "emoji")
      local title=$(_get_category_info "$category" "title")
      local description=$(_get_category_info "$category" "description")

      echo -e "${GRAY}${emoji} ${title}${NC}"
      echo -e "${GRAY}   ${description}${NC}"
      echo ""

      # Get detailed command info from inline data
      echo "$commands_data" | tail -n +2 | while IFS=',' read -r cat cmd brief verbose alias_type safety_level example; do
        if [[ "$cat" == "$category" ]]; then
          local safety_color=""
          local safety_icon=""
          case "$safety_level" in
            "safe") safety_color="$GREEN"; safety_icon="✅" ;;
            "caution") safety_color="$YELLOW_BOLD"; safety_icon="⚠️" ;;
            "dangerous") safety_color="$RED"; safety_icon="🚨" ;;
          esac

          echo -e "     ${YELLOW_BOLD}${cmd}${NC} ${safety_color}${safety_icon}${NC} ${verbose}"
          [[ -n "$example" && "$example" != "$cmd" ]] && echo -e "       ${GRAY}Example: ${CYAN}${example}${NC}"
          echo ""
        fi
      done
    done
  else
    # Verbose mode (default)
    # Loop through categories from CSV
    for category in "${categories[@]}"; do
      local emoji=$(_get_category_info "$category" "emoji")
      local title=$(_get_category_info "$category" "title")

      # Add spacing above category header
      echo ""
      # Align category header with command descriptions (15 chars + 3 spaces = 18 chars)
      echo -e "                  \033[1;4m${title}\033[0m"
      # Add spacing below category header
      echo ""

      # Get commands for this category
      _get_category_commands "$category" | while IFS=':' read -r cmd desc; do
        _print_command "$cmd" "$desc"
      done
      echo ""
    done
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# 🛠️  HELP SYSTEM UTILITIES
# ────────────────────────────────────────────────────────────────────────────────

# Add a new command to the help system
function help_add() {
  if [[ $# -lt 4 ]]; then
    echo "Usage: help_add <category> <command> <brief> <verbose> [alias_type] [safety_level] [example]"
    echo ""
    echo "Available categories: git node nav dev spendcloud proframe flow util"
    echo "Safety levels: safe, caution, dangerous"
    echo "Alias types: alias, function"
    return 1
  fi

  local category="$1"
  local command="$2"
  local brief="$3"
  local verbose="$4"
  local alias_type="${5:-alias}"
  local safety_level="${6:-safe}"
  local example="${7:-$command}"

  # Create the new command line to add
  local new_command_line="$category,$command,$brief,$verbose,$alias_type,$safety_level,$example"

  # Add to the inline commands_data in the help function
  # This is a simplified version - in practice, you'd want to edit the .zshrc file directly
  echo "✅ Command ready to add: '$command' to category '$category'"
  echo "📝 Add this line to the commands_data in your .zshrc help function:"
  echo "   $new_command_line"
  echo "💡 Then run 'source ~/.zshrc' to see the changes"
}

# Add a new category to the help system
function help_add_category() {
  if [[ $# -lt 4 ]]; then
    echo "Usage: help_add_category <key> <emoji> <title> <description>"
    return 1
  fi

  local key="$1"
  local emoji="$2"
  local title="$3"
  local description="$4"

  # Create the new category line to add
  local new_category_line="$key,$emoji,$title,$description"

  echo "✅ Category ready to add: '$key' with title '$title'"
  echo "📝 Add this line to the categories_data in your .zshrc help function:"
  echo "   $new_category_line"
  echo "💡 Then run 'source ~/.zshrc' to see the changes"
}
# ────────────────────────────────────────────────────────────────────────────────
# 🎯 END OF CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────
# Use 'help' or 'help -v' to see all available commands and aliases
# Happy coding! 🚀
