#!/usr/bin/env zsh
# ~/.zshrc - Interactive Zsh configuration for development environment.
# Applies Google Shell Style Guide concepts where compatible with Zsh
# (quoting, [[ tests, safer loops, function naming) while retaining
# zsh-specific features (oh-my-zsh, plugins, prompt frameworks).
# shellcheck shell=bash disable=SC1071,SC2034,SC1091,SC2164,SC2155,SC2119,SC2120,SC2086,SC2207
# NOTE: Some stylistic Bash-only recommendations (e.g. strict mode with set -euo pipefail)
# are intentionally omitted because this file configures an interactive shell.
# Many "issues" reported by shellcheck are normal zsh patterns and don't need fixing.

# ────────────────────────────────────────────────────────────────────────────────
# HELPERS
# ────────────────────────────────────────────────────────────────────────────────

function _zshrc_source_if_exists() {
  local target="${1}"
  [[ -f "${target}" ]] && source "${target}"
}

function _zshrc_prepend_path() {
  local candidate="${1}"
  [[ -n "${candidate}" && -d "${candidate}" ]] || return 0
  path=("${candidate}" "${path[@]}")
}

function _zshrc_unalias_conflicts() {
  local alias_name
  local -a aliases_to_clear=(
    glp gd gdc pr development repros forks projects dir clone cloned cloner
    clonef clonep coded serve cluster migrate nuke
  )
  for alias_name in "${aliases_to_clear[@]}"; do
    unalias "${alias_name}" 2>/dev/null || true
  done
}

function _zshrc_clean_broken_docker_completions() {
  local completion_dir="/usr/share/zsh/vendor-completions"
  [[ -d "${completion_dir}" ]] || return 0
  command -v sudo >/dev/null 2>&1 || return 0

  local comp_file
  for comp_file in "${completion_dir}"/_docker*; do
    [[ -L "${comp_file}" && ! -e "${comp_file}" ]] || continue
    sudo rm -f "${comp_file}" 2>/dev/null || true
  done
}

typeset -gU path fpath

# ────────────────────────────────────────────────────────────────────────────────
# SHELL CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

export ZSH="${HOME}/.oh-my-zsh"

fpath+=("${HOME}/.zsh/plugins")
fpath+=("${HOME}/.zsh/pure")
# Add repo-local custom plugin path (git-identity lives here)
fpath+=("${HOME}/projects/dotfiles/.zsh/plugins")

_zshrc_unalias_conflicts

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-z
  you-should-use
  ssh-transfer
  remote-prepare
  spend-cloud
  git-identity
)

if [[ -f "${ZSH}/oh-my-zsh.sh" ]]; then
  source "${ZSH}/oh-my-zsh.sh"
else
  printf '[zshrc] Warning: oh-my-zsh not found at %s/oh-my-zsh.sh (skipping)\n' "${ZSH}" >&2
fi

_zshrc_unalias_conflicts

# ────────────────────────────────────────────────────────────────────────────────
# PURE PROMPT CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

PURE_CMD_MAX_EXEC_TIME=3
PURE_GIT_PULL=0
PURE_GIT_UNTRACKED_DIRTY=1

zstyle :prompt:pure:environment:nix-shell show no
zstyle :prompt:pure:path color 250
zstyle :prompt:pure:git:dirty color 204
zstyle :prompt:pure:git:branch color 244
zstyle :prompt:pure:prompt:success color green
zstyle :prompt:pure:prompt:error color red

autoload -Uz promptinit
promptinit
prompt pure

# git-identity prompt location (left|right|both). Uncomment to move segment.
export GIT_ID_PROMPT_SIDE=left

export GIT_ID_PERSONAL_NAME="dpdd"
export GIT_ID_PERSONAL_EMAIL="dpdd@squat.net"
export GIT_ID_PERSONAL_KEY="${HOME}/.ssh/dpdd-github"
export GIT_ID_WORK_NAME="Tom"
export GIT_ID_WORK_EMAIL="tom.van.veen@visma.com"
export GIT_ID_WORK_KEY="${HOME}/.ssh/id_rsa"

alias edit-pure='${EDITOR:-vi} +/PURE\ PROMPT\ CONFIGURATION ~/.zshrc'

# ────────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT SETUP
# ────────────────────────────────────────────────────────────────────────────────

# Node Version Manager (NVM)
export NVM_DIR="${HOME}/.nvm"
_zshrc_source_if_exists "${NVM_DIR}/nvm.sh"
_zshrc_source_if_exists "${NVM_DIR}/bash_completion"

# Homebrew (Linux)
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Google Cloud SDK
_zshrc_source_if_exists '/home/tom/google-cloud-sdk/path.zsh.inc'
_zshrc_source_if_exists '/home/tom/google-cloud-sdk/completion.zsh.inc'
_zshrc_prepend_path "${HOME}/google-cloud-sdk/bin"

# PNPM package manager
export PNPM_HOME="${HOME}/.local/share/pnpm"
_zshrc_prepend_path "${PNPM_HOME}"
alias pn=pnpm

# Python environment management (pyenv)
export PYENV_ROOT="${HOME}/.pyenv"
_zshrc_prepend_path "${PYENV_ROOT}/bin"

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  if command -v pyenv-virtualenv >/dev/null 2>&1 || pyenv commands | grep -q virtualenv; then
    eval "$(pyenv virtualenv-init -)"
  fi
fi

# ASDF version manager (optional)
_zshrc_source_if_exists "${HOME}/.asdf/asdf.sh"

# Additional PATH entries
_zshrc_prepend_path "${HOME}/.composer/vendor/bin"
if command -v yarn >/dev/null 2>&1; then
  _zshrc_prepend_path "$(yarn global bin)"
fi
_zshrc_prepend_path "${HOME}/.local/bin"

# ────────────────────────────────────────────────────────────────────────────────
# NODE.JS WORKFLOW ALIASES
# ────────────────────────────────────────────────────────────────────────────────

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
# GIT ALIASES
# ────────────────────────────────────────────────────────────────────────────────

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
# GIT FUNCTIONS
# ────────────────────────────────────────────────────────────────────────────────

# Display git log with specified number of commits (default: 20).
glp() {
  local c="${1:-20}"
  [[ "${c}" =~ ^[0-9]+$ ]] || {
    echo 'glp: numeric count' >&2
    return 2
  }
  git --no-pager log -"${c}"
}

# Show git diff with fancy formatting (optionally for specific file).
gd() {
  if [[ -z "${1:-}" ]]; then
    git diff --color | diff-so-fancy
  else
    git diff --color -- "${1}" | diff-so-fancy
  fi
}

# Show git diff --cached with fancy formatting (optionally for specific file).
gdc() {
  if [[ -z "${1:-}" ]]; then
    git diff --color --cached | diff-so-fancy
  else
    git diff --color --cached -- "${1}" | diff-so-fancy
  fi
}

# PR helper: list PRs with 'pr ls' or checkout PR by number 'pr 123'.
pr() {
  if [[ -z "${1:-}" ]]; then
    echo 'usage: pr <ls|num>' >&2
    return 2
  fi
  if [[ "${1}" == "ls" ]]; then
    gh pr list
  else
    gh pr checkout "${1}"
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# DIRECTORY NAVIGATION
# ────────────────────────────────────────────────────────────────────────────────

# Navigate to subdirectory in ~/development
development() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: development <dir>' >&2
    return 2
  }
  cd "${HOME}/development/${1}" || return 1
}

# Navigate to subdirectory in ~/repros
repros() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: repros <dir>' >&2
    return 2
  }
  cd "${HOME}/repros/${1}" || return 1
}

# Navigate to subdirectory in ~/forks
forks() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: forks <dir>' >&2
    return 2
  }
  cd "${HOME}/forks/${1}" || return 1
}

# Navigate to subdirectory in ~/projects
projects() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: projects <dir>' >&2
    return 2
  }
  cd "${HOME}/projects/${1}" || return 1
}

# Create directory and cd into it
dir() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: dir <new-dir>' >&2
    return 2
  }
  mkdir -p -- "${1}" && cd "${1}" || return 1
}

# Clone repository with gh and cd into it
clone() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: clone <repo> [dir]' >&2
    return 2
  }
  if [[ -z "${2:-}" ]]; then
    gh repo clone "$@" && cd "$(basename "${1}" .git)" || return 1
  else
    gh repo clone "$@" && cd "${2}" || return 1
  fi
}

# Clone to ~/development, open in VS Code, return to previous directory
cloned() {
  development && clone "$@" && code . && cd ~2
}

# Clone to ~/repros, open in VS Code, return to previous directory
cloner() {
  repros && clone "$@" && code . && cd ~2
}

# Clone to ~/forks, open in VS Code, return to previous directory
clonef() {
  forks && clone "$@" && code . && cd ~2
}

# Clone to ~/projects, open in VS Code, return to previous directory
clonep() {
  projects && clone "$@" && code . && cd ~2
}

# Open VS Code in development directory
coded() {
  development && code "$@" && cd -
}

# Start live-server for local development (default: dist/)
serve() {
  if [[ -z "${1:-}" ]]; then
    live-server dist
  else
    live-server "${1}"
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# HELP SYSTEM
# ────────────────────────────────────────────────────────────────────────────────

help() {
  local help_file="${HOME}/.zshrc.help.md"

  [[ -f "${help_file}" ]] || {
    echo "Help file missing: ${help_file}" >&2
    return 1
  }

  if command -v glow >/dev/null 2>&1; then
    glow "${help_file}"
  else
    cat "${help_file}"
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# WSL & COMPLETION FIXES
# ────────────────────────────────────────────────────────────────────────────────

_zshrc_clean_broken_docker_completions

setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# ────────────────────────────────────────────────────────────────────────────────
# LOCAL PLUGINS / EXTENSIONS
# ────────────────────────────────────────────────────────────────────────────────

# git-identity plugin is loaded via plugins array. (See .zsh/plugins/git-identity)
