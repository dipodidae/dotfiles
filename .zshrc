#!/usr/bin/env zsh
# shellcheck shell=bash disable=SC1071,SC2034,SC1091,SC2164,SC2155,SC2119,SC2120,SC2086,SC2207
# Note: This is a zsh config file. Some zsh-specific syntax may not be fully compatible with shellcheck.
# Many "issues" reported by shellcheck are normal zsh patterns and don't need fixing.

# ────────────────────────────────────────────────────────────────────────────────
# SHELL CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

# Oh My Zsh setup
export ZSH="$HOME/.oh-my-zsh"

# Zsh plugins configuration
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-z
  you-should-use
)

# Load Oh My Zsh
# shellcheck disable=SC1091
source "$ZSH/oh-my-zsh.sh"

# ────────────────────────────────────────────────────────────────────────────────
# PURE PROMPT CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

# Ensure Pure is available (manual install path)
fpath+=("$HOME/.zsh/pure")

# Core Pure options
PURE_CMD_MAX_EXEC_TIME=3
PURE_GIT_PULL=0
PURE_GIT_UNTRACKED_DIRTY=1

# Feature toggles via zstyle
zstyle :prompt:pure:git:stash show yes
zstyle :prompt:pure:environment:nix-shell show no

# Color tweaks
zstyle :prompt:pure:path color 250
zstyle :prompt:pure:git:dirty color 204
zstyle :prompt:pure:git:branch color 244
zstyle :prompt:pure:prompt:success color green
zstyle :prompt:pure:prompt:error color red

# Initialize Pure
autoload -U promptinit; promptinit
prompt pure

# Convenience: jump to this section quickly
alias edit-pure='${EDITOR:-vi} +/PURE\ PROMPT\ CONFIGURATION ~/.zshrc'

# ────────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT SETUP
# ────────────────────────────────────────────────────────────────────────────────

# Node Version Manager (NVM)
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ────────────────────────────────────────────────────────────────────────────────
# NODE.JS & PACKAGE MANAGEMENT
# ────────────────────────────────────────────────────────────────────────────────
# https://github.com/antfu/ni

alias nio="ni --prefer-offline"
alias s="nr start"
alias b="nr build"
alias bw="nr build --watch"
alias t="nr test"
alias tu="nr test -u"
alias tw="nr test --watch"
alias w="nr watch"
alias p="nr play"
alias c="nr typecheck"
alias lint="nr lint"
alias lintf="nr lint --fix"
alias release="nr release"
alias re="nr release"

# ────────────────────────────────────────────────────────────────────────────────
# GIT CONFIGURATION & ALIASES
# ────────────────────────────────────────────────────────────────────────────────

# Go to project root
alias grt='cd "$(git rev-parse --show-toplevel)"'

alias gs='git status'
alias gp='git push'
alias gpf='git push --force'
alias gpft='git push --follow-tags'
alias gpl='git pull --rebase'
alias gcl='git clone'
alias gst='git stash'
alias grm='git rm'
alias gmv='git mv'

alias main='git checkout main'

alias gco='git checkout'
alias gcob='git checkout -b'

alias gb='git branch'
alias gbd='git branch -d'

alias grb='git rebase'
alias grbom='git rebase origin/master'
alias grbc='git rebase --continue'

alias gl='git log'
alias glo='git log --oneline --graph'

alias grh='git reset HEAD'
alias grh1='git reset HEAD~1'

alias ga='git add'
alias gA='git add -A'

alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit -a'
alias gcam='git add -A && git commit -m'
alias gfrb='git fetch origin && git rebase origin/master'

alias gxn='git clean -dn'
alias gx='git clean -df'

alias gsha='git rev-parse HEAD | pbcopy'

alias ghci='gh run list -L 1'

# ────────────────────────────────────────────────────────────────────────────────
# PROJECT-SPECIFIC SHORTCUTS
# ────────────────────────────────────────────────────────────────────────────────

# SpendCloud Project Navigation
alias sc='cd ~/development/spend-cloud'
alias scapi='sc && cd api'
alias scui='sc && cd ui'
alias cui='code ~/development/spend-cloud/ui'
alias capi='code ~/development/spend-cloud/api'
alias devapi='scapi && sct dev'

# Proactive Frame Project
alias pf='cd ~/development/proactive-frame'
alias cpf='code ~/development/proactive-frame'

# ────────────────────────────────────────────────────────────────────────────────
# DEVELOPMENT FUNCTIONS
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
  local original_dir=$(pwd)

  # Handle stop command
  if [[ "$1" == "stop" ]]; then
    echo -e "${YELLOW}🛑 Stopping all cluster services...${NC}"

    # Stop and remove development containers first
    echo -e "${CYAN}🔍 Stopping and removing all containers...${NC}"
    local dev_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)")
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
  local dev_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)" | head -15)

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
  cd ~/development/spend-cloud/api
  sct dev > /dev/null 2>&1 &

  echo -e "${CYAN}⚡ Starting dev for spend-cloud/proactive-frame...${NC}"
  cd ~/development/proactive-frame
  sct dev > /dev/null 2>&1 &

  # Return to the original directory
  cd "$original_dir"

  echo -e "${GREEN}✅ All services started!${NC}"
  echo -e "${WHITE}🌟 SCT cluster is running and dev services are running in the background.${NC}"
}

# Database Migration Management
function migrate() {
  local container
  container=$(docker ps --format '{{.Names}}' | grep -E 'spend.*cloud.*api|api.*spend.*cloud' | head -1)
  if [[ -z "$container" ]]; then
    echo "API container not found. Start with 'cluster'."
    return 1
  fi
  local action="${1:-all}"
  case "$action" in
    all)
      docker exec -it "$container" php artisan migrate-all --groups=customers,proactive_config,proactive-default,sharedStorage ;;
    customers)
      docker exec -it "$container" php artisan migrate --path=database/migrations/customers ;;
    config)
      docker exec -it "$container" php artisan migrate --path=database/migrations/config ;;
    shared|sharedstorage)
      docker exec -it "$container" php artisan migrate --path=database/migrations/sharedStorage ;;
    rollback)
      local target="${2:-customers}"
      case "$target" in
        customers) docker exec -it "$container" php artisan migrate:rollback --path=database/migrations/customers ;;
        config) docker exec -it "$container" php artisan migrate:rollback --path=database/migrations/config ;;
        shared|sharedstorage) docker exec -it "$container" php artisan migrate:rollback --path=database/migrations/sharedStorage ;;
        *) echo "Invalid rollback target: $target"; return 1 ;;
      esac
      ;;
    help|-h|--help)
      echo "Usage: migrate [all|customers|config|shared|rollback [customers|config|shared]]"
      return 0 ;;
    *)
      echo "Invalid migrate option: $action"
      echo "Usage: migrate [all|customers|config|shared|rollback [customers|config|shared]]"
      return 1 ;;
  esac
}

# Git utility functions
function glp() {
  git --no-pager log -$1
}

function gd() {
  if [[ -z $1 ]]; then
    git diff --color | diff-so-fancy
  else
    git diff --color $1 | diff-so-fancy
  fi
}

function gdc() {
  if [[ -z $1 ]]; then
    git diff --color --cached | diff-so-fancy
  else
    git diff --color --cached $1 | diff-so-fancy
  fi
}

# Pull Request management
function pr() {
  if [ $1 = "ls" ]; then
    gh pr list
  else
    gh pr checkout $1
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# DIRECTORY NAVIGATION & MANAGEMENT
# ────────────────────────────────────────────────────────────────────────────────

function development() {
  cd ~/development/$1
}

function repros() {
  cd ~/repros/$1
}

function forks() {
  cd ~/forks/$1
}

function projects() {
  cd ~/projects/$1
}

function dir() {
  mkdir $1 && cd $1
}

# ────────────────────────────────────────────────────────────────────────────────
# REPOSITORY CLONING & CODE MANAGEMENT
# ────────────────────────────────────────────────────────────────────────────────

function clone() {
  if [[ -z $2 ]]; then
    gh repo clone "$@" && cd "$(basename "$1" .git)"
  else
    gh repo clone "$@" && cd "$2"
  fi
}

# Clone to ~/development and cd to it
function cloned() {
  development && clone "$@" && code . && cd ~2
}

function cloner() {
  repros && clone "$@" && code . && cd ~2
}

function clonef() {
  forks && clone "$@" && code . && cd ~2
}

function clonep() {
  projects && clone "$@" && code . && cd ~2
}

function coded() {
  development && code "$@" && cd -
}

function serve() {
  if [[ -z $1 ]]; then
    live-server dist
  else
    live-server $1
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# SYSTEM ENVIRONMENT SETUP
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
# Add yarn global bin to PATH if yarn is available
if command -v yarn >/dev/null 2>&1; then
    export PATH="$PATH:$(yarn global bin)"
fi
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
# Only initialize pyenv virtualenv if available (fixes WSL error)
if command -v pyenv-virtualenv >/dev/null 2>&1 || pyenv commands | grep -q virtualenv; then
  eval "$(pyenv virtualenv-init -)"
fi

# ASDF version manager
## <SPEND_CLOUD_ASDF>
## Written on 02-06-2025 at 16:51:11
if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
    . "$HOME/.asdf/asdf.sh"
fi
## </SPEND_CLOUD_ASDF>

# ────────────────────────────────────────────────────────────────────────────────
# HELP SYSTEM
# ────────────────────────────────────────────────────────────────────────────────

function help() {
  local help_file="$HOME/.zshrc.help.md"

  if [[ ! -f "$help_file" ]]; then
    echo "Help file not found at $help_file"
    echo "Please run the installer to set up documentation."
    return 1
  fi

  if command -v glow >/dev/null 2>&1; then
    # shellcheck disable=SC2002
    cat "$help_file" | glow -
  else
    echo "Error: glow is not installed. Please run the installer to set up the complete environment."
    echo "Fallback: cat $help_file"
    cat "$help_file"
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# WSL & COMPLETION FIXES
# ────────────────────────────────────────────────────────────────────────────────

# Fix docker completion errors in WSL/environments where docker completions are missing
# This prevents the "compinit:527: no such file or directory: /usr/share/zsh/vendor-completions/_docker" error
if [[ -d "/usr/share/zsh/vendor-completions" ]]; then
  # Remove any broken docker completion symlinks/files that cause errors
  for comp_file in /usr/share/zsh/vendor-completions/_docker*; do
    if [[ -L "$comp_file" && ! -e "$comp_file" ]]; then
      # It's a broken symlink, try to remove it (if we have permission)
      sudo rm -f "$comp_file" 2>/dev/null || true
    fi
  done
fi

# Alternative: Skip missing completions gracefully
# This ensures compinit doesn't fail on missing completion files
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

