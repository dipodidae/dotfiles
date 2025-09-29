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
# SHELL CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

# Oh My Zsh setup
export ZSH="${HOME}/.oh-my-zsh"

# Unalias potentially conflicting names (pre-plugin load) so that if any were
# previously defined in login shell fragments they don't interfere.
for __sc_fn in glp gd gdc pr development repros forks projects dir clone cloned cloner clonef clonep coded serve cluster migrate nuke; do
  unalias "${__sc_fn}" 2> /dev/null || true
done
unset __sc_fn

# Zsh plugins configuration
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-z
  you-should-use
)

# Load Oh My Zsh if present (avoid hard failure if not installed yet)
# shellcheck disable=SC1091
if [[ -f "${ZSH}/oh-my-zsh.sh" ]]; then
  source "${ZSH}/oh-my-zsh.sh"
else
  echo "[zshrc] Warning: oh-my-zsh not found at ${ZSH}/oh-my-zsh.sh (skipping)" >&2
fi

for __sc_fn in glp gd gdc pr development repros forks projects dir clone cloned cloner clonef clonep coded serve cluster migrate nuke; do
  unalias "${__sc_fn}" 2> /dev/null || true
done
unset __sc_fn

# ────────────────────────────────────────────────────────────────────────────────
# PURE PROMPT CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

# Ensure Pure is available (manual install path)
fpath+=("${HOME}/.zsh/pure")

# Core Pure options
PURE_CMD_MAX_EXEC_TIME=3
PURE_GIT_PULL=0
PURE_GIT_UNTRACKED_DIRTY=1

# Feature toggles via zstyle
zstyle :prompt:pure:environment:nix-shell show no

# Color tweaks
zstyle :prompt:pure:path color 250
zstyle :prompt:pure:git:dirty color 204
zstyle :prompt:pure:git:branch color 244
zstyle :prompt:pure:prompt:success color green
zstyle :prompt:pure:prompt:error color red

# Initialize Pure
autoload -U promptinit
promptinit
prompt pure

# Convenience: jump to this section quickly
alias edit-pure='${EDITOR:-vi} +/PURE\ PROMPT\ CONFIGURATION ~/.zshrc'

# ────────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT SETUP
# ────────────────────────────────────────────────────────────────────────────────

# Node Version Manager (NVM)
export NVM_DIR="${HOME}/.nvm"
# shellcheck disable=SC1091
[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"
# shellcheck disable=SC1091
[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"

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
# (moved to optional spend-cloud/proactive module; see ENABLE_SPEND_CLOUD below)

# ────────────────────────────────────────────────────────────────────────────────
# (Development functions cluster, migrate, nuke, git/pr helpers moved to optional module)

# ────────────────────────────────────────────────────────────────────────────────

# Git helpers & PR

#######################################
# Display git log with specified number of commits.
# Arguments:
#   Number of commits to show (default: 20)
# Outputs:
#   Git log to stdout
# Returns:
#   0 on success, 2 on invalid argument
#######################################
glp() {
  local c="${1:-20}"
  [[ "${c}" =~ ^[0-9]+$ ]] || {
    echo 'glp: numeric count' >&2
    return 2
  }
  git --no-pager log -"${c}"
}

#######################################
# Show git diff with fancy formatting.
# Arguments:
#   Optional file path to diff
# Outputs:
#   Formatted git diff to stdout
#######################################
gd() {
  if [[ -z "${1:-}" ]]; then
    git diff --color | diff-so-fancy
  else
    git diff --color -- "${1}" | diff-so-fancy
  fi
}

#######################################
# Show git diff --cached with fancy formatting.
# Arguments:
#   Optional file path to diff
# Outputs:
#   Formatted git diff --cached to stdout
#######################################
gdc() {
  if [[ -z "${1:-}" ]]; then
    git diff --color --cached | diff-so-fancy
  else
    git diff --color --cached -- "${1}" | diff-so-fancy
  fi
}

#######################################
# PR helper: list PRs or checkout PR by number.
# Arguments:
#   'ls' to list PRs, or PR number to checkout
# Outputs:
#   PR list or checkout status to stdout
# Returns:
#   0 on success, 2 on invalid usage
#######################################
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

# Directory helpers

#######################################
# Navigate to development directory.
# Arguments:
#   Directory name under ~/development
# Returns:
#   0 on success, 1 if cd fails, 2 on invalid usage
#######################################
development() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: development <dir>' >&2
    return 2
  }
  cd "${HOME}/development/${1}" || return 1
}

#######################################
# Navigate to repros directory.
# Arguments:
#   Directory name under ~/repros
# Returns:
#   0 on success, 1 if cd fails, 2 on invalid usage
#######################################
repros() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: repros <dir>' >&2
    return 2
  }
  cd "${HOME}/repros/${1}" || return 1
}

#######################################
# Navigate to forks directory.
# Arguments:
#   Directory name under ~/forks
# Returns:
#   0 on success, 1 if cd fails, 2 on invalid usage
#######################################
forks() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: forks <dir>' >&2
    return 2
  }
  cd "${HOME}/forks/${1}" || return 1
}

#######################################
# Navigate to projects directory.
# Arguments:
#   Directory name under ~/projects
# Returns:
#   0 on success, 1 if cd fails, 2 on invalid usage
#######################################
projects() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: projects <dir>' >&2
    return 2
  }
  cd "${HOME}/projects/${1}" || return 1
}

#######################################
# Create directory and navigate to it.
# Arguments:
#   Directory name to create
# Returns:
#   0 on success, 1 if mkdir or cd fails, 2 on invalid usage
#######################################
dir() {
  [[ -n "${1:-}" ]] || {
    echo 'usage: dir <new-dir>' >&2
    return 2
  }
  mkdir -p -- "${1}" && cd "${1}" || return 1
}

# Clone helpers

#######################################
# Clone a repository and navigate to it.
# Arguments:
#   Repository to clone
#   Optional directory name
# Returns:
#   0 on success, 1 if clone or cd fails, 2 on invalid usage
#######################################
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

#######################################
# Clone to development directory and open in VS Code.
# Arguments:
#   Repository and optional directory arguments
#######################################
cloned() {
  development && clone "$@" && code . && cd ~2
}

#######################################
# Clone to repros directory and open in VS Code.
# Arguments:
#   Repository and optional directory arguments
#######################################
cloner() {
  repros && clone "$@" && code . && cd ~2
}

#######################################
# Clone to forks directory and open in VS Code.
# Arguments:
#   Repository and optional directory arguments
#######################################
clonef() {
  forks && clone "$@" && code . && cd ~2
}

#######################################
# Clone to projects directory and open in VS Code.
# Arguments:
#   Repository and optional directory arguments
#######################################
clonep() {
  projects && clone "$@" && code . && cd ~2
}

#######################################
# Open VS Code in development directory.
# Arguments:
#   Directory or file arguments for VS Code
#######################################
coded() {
  development && code "$@" && cd -
}

#######################################
# Start live-server for local development.
# Arguments:
#   Optional directory to serve (default: dist)
#######################################
serve() {
  if [[ -z "${1:-}" ]]; then
    live-server dist
  else
    live-server "${1}"
  fi
}
# ────────────────────────────────────────────────────────────────────────────────
# SYSTEM ENVIRONMENT SETUP
# ────────────────────────────────────────────────────────────────────────────────

# Homebrew (Linux)
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Google Cloud SDK
if [[ -f '/home/tom/google-cloud-sdk/path.zsh.inc' ]]; then
  . '/home/tom/google-cloud-sdk/path.zsh.inc'
fi
if [[ -f '/home/tom/google-cloud-sdk/completion.zsh.inc' ]]; then
  . '/home/tom/google-cloud-sdk/completion.zsh.inc'
fi

# (SpendCloud-specific PATH blocks moved to optional module)

# PNPM package manager
export PNPM_HOME="${HOME}/.local/share/pnpm"
case ":${PATH}:" in
  *":${PNPM_HOME}:"*) ;;
  *) export PATH="${PNPM_HOME}:${PATH}" ;;
esac

# PNPM alias for shorter commands
alias pn=pnpm

# Python environment management (pyenv)
export PYENV_ROOT="${HOME}/.pyenv"
export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
# Only initialize pyenv virtualenv if available (fixes WSL error)
if command -v pyenv-virtualenv > /dev/null 2>&1 || pyenv commands | grep -q virtualenv; then
  eval "$(pyenv virtualenv-init -)"
fi

# (ASDF initialization moved to optional module)

# ────────────────────────────────────────────────────────────────────────────────
# OPTIONAL PROJECT MODULE LOADER (SpendCloud / Proactive)
# ────────────────────────────────────────────────────────────────────────────────
# To enable project-specific functions & aliases, either:
#   export ENABLE_SPEND_CLOUD=1 (in ~/.zshrc.local or before starting shell)
#   or run: enable-spend-cloud
_SPEND_CLOUD_OPT_FILE="${HOME}/.zsh/spend-cloud.optional.zsh"
if [[ -n "${ENABLE_SPEND_CLOUD:-}" && -f "${_SPEND_CLOUD_OPT_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${_SPEND_CLOUD_OPT_FILE}"
fi
#######################################
# Enable SpendCloud optional module.
# Globals:
#   ENABLE_SPEND_CLOUD
#   _SPEND_CLOUD_OPT_FILE
# Outputs:
#   Status message to stdout or stderr
#######################################
enable-spend-cloud() {
  export ENABLE_SPEND_CLOUD=1
  if [[ -f "${_SPEND_CLOUD_OPT_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${_SPEND_CLOUD_OPT_FILE}"
    echo "SpendCloud module loaded"
  else
    echo "SpendCloud optional file missing: ${_SPEND_CLOUD_OPT_FILE}" >&2
  fi
}

#######################################
# Disable SpendCloud optional module.
# Globals:
#   ENABLE_SPEND_CLOUD
# Outputs:
#   Status message to stdout
#######################################
disable-spend-cloud() {
  unset ENABLE_SPEND_CLOUD
  echo "SpendCloud module disabled (restart shell to fully unload)."
}

# ────────────────────────────────────────────────────────────────────────────────
# HELP SYSTEM
# ────────────────────────────────────────────────────────────────────────────────

#######################################
# Display help documentation using glow or cat fallback.
# Outputs:
#   Help documentation to stdout
# Returns:
#   0 on success, 1 if help file not found
#######################################
help() {
  local help_file="${HOME}/.zshrc.help.md"

  if [[ ! -f "${help_file}" ]]; then
    echo "Help file not found at ${help_file}"
    echo "Please run the installer to set up documentation."
    return 1
  fi

  if command -v glow > /dev/null 2>&1; then
    # shellcheck disable=SC2002
    cat "${help_file}" | glow -
  else
    echo "Error: glow is not installed. Please run the installer to set up the complete environment."
    echo "Fallback: cat ${help_file}"
    cat "${help_file}"
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
    if [[ -L "${comp_file}" && ! -e "${comp_file}" ]]; then
      # It's a broken symlink, try to remove it (if we have permission)
      sudo rm -f "${comp_file}" 2> /dev/null || true
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

# (All project-specific & destructive helpers now isolated; base shell is lean)
