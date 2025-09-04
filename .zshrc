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

# Use github/hub
alias git=hub

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
function cluster() {
  local sub="$1"
  case "$sub" in
    ''|start)
      if [[ "$sub" == '--rebuild' || "$2" == '--rebuild' ]]; then
        sct cluster start --build --pull || return 1
      elif [[ "$1" == '--rebuild' ]]; then
        sct cluster start --build --pull || return 1
      else
        sct cluster start || return 1
      fi
      (cd ~/development/spend-cloud/api 2>/dev/null && sct dev >/dev/null 2>&1 &)
      (cd ~/development/proactive-frame 2>/dev/null && sct dev >/dev/null 2>&1 &)
      ;;
    --rebuild)
      sct cluster start --build --pull || return 1
      (cd ~/development/spend-cloud/api 2>/dev/null && sct dev >/dev/null 2>&1 &)
      (cd ~/development/proactive-frame 2>/dev/null && sct dev >/dev/null 2>&1 &)
      ;;
    stop)
      sct cluster stop
      ;;
    logs)
      if [[ -n "$2" ]]; then
        sct cluster logs "$2"
      else
        sct cluster logs
      fi
      ;;
    help|-h|--help)
      echo "Usage: cluster [start|--rebuild|stop|logs [service]]"
      ;;
    *)
      echo "Unknown cluster subcommand: $sub"
      echo "Usage: cluster [start|--rebuild|stop|logs [service]]"
      return 1
      ;;
  esac
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
  if [[ -z $1 ]] then
    git diff --color | diff-so-fancy
  else
    git diff --color $1 | diff-so-fancy
  fi
}

function gdc() {
  if [[ -z $1 ]] then
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
  if [[ -z $2 ]] then
    hub clone "$@" && cd "$(basename "$1" .git)"
  else
    hub clone "$@" && cd "$2"
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
  if [[ -z $1 ]] then
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
eval "$(pyenv virtualenv-init -)"

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

