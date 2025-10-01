#!/usr/bin/env zsh
# git-identity.plugin.zsh
# Enhanced with elements of emerging Zsh Plugin Standard:
#  - Robust $0 handling for directory resolution
#  - State hash & Plugins registry entry
#  - Double-load guard
#  - Optional functions/ directory integration
#  - Unload hook function (git_identity_plugin_unload)
#  - emulate wrapper for predictable option environment
# Lightweight multi Git identity manager WITHOUT SSH host aliases or new keys.
#
# Features:
#   - Per-repo identity switch (personal / work) via `git-identity set <profile>`.
#   - Auto-detection (optional) based on path or remote origin.
#   - Prompt indicator: (work) / (personal) appended to RPROMPT.
#   - Stores settings ONLY in local repo (user.name, user.email, core.sshCommand).
#   - Zero global git config mutation.
#
# Commands:
#   git-identity show      # Show current repo identity info
#   git-identity set <p>   # p = personal|work (applies identity)
#   git-identity auto on   # Enable auto mode (directory/remote-based)
#   git-identity auto off  # Disable auto mode
#   git-identity status    # Alias of show
#   git-identity help      # Quick help
#
# Configuration (define BEFORE loading plugin, e.g. in ~/.zshrc):
#   GIT_ID_PERSONAL_NAME
#   GIT_ID_PERSONAL_EMAIL
#   GIT_ID_PERSONAL_KEY (default: ~/.ssh/dpdd-github)
#   GIT_ID_WORK_NAME
#   GIT_ID_WORK_EMAIL
#   GIT_ID_WORK_KEY      (default: ~/.ssh/id_rsa)
#   GIT_ID_AUTO_DEFAULT=1   # Start with auto mode enabled
#   GIT_ID_HIDE_PROMPT=1    # Disable prompt segment
#
# Auto-detect "work" if:
#   * $PWD contains '/development/spend-cloud'
#   * OR remote.origin.url contains 'Spend-Cloud'
# Otherwise -> personal.
#
# Implementation Notes:
#   * We rely on `core.sshCommand` to force the correct key explicitly.
#   * Fallback when unset email: prints (unknown) in segment.

########################################
# Standard $0 handling & plugin context
########################################
# shellcheck disable=SC2277,SC2296,SC2298,SC2299 # zsh-specific $0 resolution idiom
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# Global state containers
typeset -gA GitIdentityState
GitIdentityState[dir]="${0:h}"

if ! typeset -p Plugins &>/dev/null; then
  typeset -gA Plugins
fi
Plugins[git_identity_dir]="${0:h}"

# Prevent double loading
if [[ -n ${GitIdentityState[loaded]:-} ]]; then
  return 0
fi
GitIdentityState[loaded]=1

# Predictable execution environment helper
_gitid_emulate() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd
}

setopt typeset_silent 2>/dev/null || true

# ------------------------- Defaults / Inference ------------------------------
: "${GIT_ID_PERSONAL_KEY:=$HOME/.ssh/dpdd-github}"
: "${GIT_ID_WORK_KEY:=$HOME/.ssh/id_rsa}"

_gitid_infer_defaults() {
  _gitid_emulate
  # Only set if absent to allow user override.
  : "${GIT_ID_PERSONAL_NAME:=Personal}"
  : "${GIT_ID_WORK_NAME:=Work}"
  : "${GIT_ID_PERSONAL_EMAIL:=personal@example.invalid}"
  : "${GIT_ID_WORK_EMAIL:=work@example.invalid}"
}
_gitid_infer_defaults

# ------------------------- Helpers -------------------------------------------
_gitid_log() { echo "[git-identity] $*" >&2; }
_gitid_in_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

_gitid_detect_profile() {
  _gitid_emulate
  _gitid_in_repo || return 1
  local remote path
  path=$PWD
  remote="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [[ $path == */development/spend-cloud* || $remote == *Spend-Cloud* ]]; then
    print -r -- work
  else
    print -r -- personal
  fi
}

_gitid_apply_profile() {
  _gitid_emulate
  local profile="$1" name email key
  case $profile in
    personal) name=$GIT_ID_PERSONAL_NAME email=$GIT_ID_PERSONAL_EMAIL key=$GIT_ID_PERSONAL_KEY ;;
    work)     name=$GIT_ID_WORK_NAME     email=$GIT_ID_WORK_EMAIL     key=$GIT_ID_WORK_KEY ;;
    *) _gitid_log "Unknown profile: $profile"; return 2 ;;
  esac
  [[ -f $key ]] || { _gitid_log "Key not found: $key"; return 3; }
  git config user.name  "$name"
  git config user.email "$email"
  git config core.sshCommand "ssh -i $key"
  _gitid_log "Applied $profile ($name <$email>) using $key"
}

_gitid_current_info() {
  _gitid_emulate
  _gitid_in_repo || { _gitid_log "Not a git repo"; return 0; }
  local name email sshcmd key profile
  name="$(git config user.name 2>/dev/null || print -r -- -)"
  email="$(git config user.email 2>/dev/null || print -r -- -)"
  sshcmd="$(git config core.sshCommand 2>/dev/null || print -r -- -)"
  # Extract key path from core.sshCommand if present. Avoid zsh (#b) glob so shellcheck
  # doesn't choke; use parameter trimming instead.
  if [[ $sshcmd == *" -i "* ]]; then
    local after=${sshcmd#*-i }
    key=${after%% *}
  else
    key="(agent/default)"
  fi
  if [[ $email == "$GIT_ID_WORK_EMAIL" ]]; then
    profile=work
  elif [[ $email == "$GIT_ID_PERSONAL_EMAIL" ]]; then
    profile=personal
  else
    profile=unknown
  fi
  printf 'Profile: %s\nName: %s\nEmail: %s\nKey: %s\nSSHCommand: %s\n' \
    "$profile" "$name" "$email" "$key" "$sshcmd"
}

# ------------------------- Public Command ------------------------------------
git-identity() {
  _gitid_emulate
  local cmd="${1:-}"
  shift || true
  case "${cmd}" in
  show | status) _gitid_current_info ;;
  set)
    local profile="${1:-}"
    shift || true
    [[ -n "${profile}" ]] || {
      _gitid_log "usage: git-identity set <personal|work>"
      return 2
    }
    _gitid_in_repo || {
      _gitid_log "Not a git repo"
      return 2
    }
    _gitid_apply_profile "${profile}"
    ;;
  auto)
    local mode="${1:-}"
    shift || true
    case "${mode}" in
    on)
      GIT_IDENTITY_AUTO=1
      _gitid_log "Auto ON"
      _gitid_auto_maybe
      ;;
    off)
      GIT_IDENTITY_AUTO=0
      _gitid_log "Auto OFF"
      ;;
    *)
      _gitid_log "usage: git-identity auto <on|off>"
      return 2
      ;;
    esac
    ;;
  help | -h | --help | '')
    cat <<'EOF'
git-identity commands:
  git-identity show            Show current repo identity
  git-identity set personal    Apply personal identity
  git-identity set work        Apply work identity
  git-identity auto on|off     Toggle auto detection mode
  git-identity status          Alias of show
  git-identity help            This help

Auto detection rules:
  path contains /development/spend-cloud OR remote contains Spend-Cloud -> work
  else -> personal

Environment vars (set before plugin load):
  GIT_ID_PERSONAL_NAME / GIT_ID_PERSONAL_EMAIL / GIT_ID_PERSONAL_KEY
  GIT_ID_WORK_NAME     / GIT_ID_WORK_EMAIL     / GIT_ID_WORK_KEY
  GIT_ID_AUTO_DEFAULT=1      Start with auto mode enabled
  GIT_ID_HIDE_PROMPT=1       Disable (work)/(personal) prompt segment
EOF
    ;;
  *)
    _gitid_log "Unknown command: ${cmd}"
    return 2
    ;;
  esac
}

# ------------------------- Auto Mode & Hooks ---------------------------------
: "${GIT_IDENTITY_AUTO:=${GIT_ID_AUTO_DEFAULT:-0}}"
_gitid_auto_maybe() {
  _gitid_emulate
  ((GIT_IDENTITY_AUTO == 1)) || return 0
  _gitid_in_repo || return 0
  local want cur
  want="$(_gitid_detect_profile)" || return 0
  cur="$(git config user.email 2>/dev/null || echo '')"
  if [[ "${want}" == work && "${cur}" != "${GIT_ID_WORK_EMAIL}" ]]; then
    _gitid_apply_profile work >/dev/null 2>&1 || true
  elif [[ "${want}" == personal && "${cur}" != "${GIT_ID_PERSONAL_EMAIL}" ]]; then
    _gitid_apply_profile personal >/dev/null 2>&1 || true
  fi
}

_gitid_prompt_segment() {
  _gitid_emulate
  ((${GIT_ID_HIDE_PROMPT:-0} == 1)) && return 0
  _gitid_in_repo || return 0
  local email="$(git config user.email 2>/dev/null || echo '')"
  [[ -z "${email}" ]] && return 0
  if [[ "${email}" == "${GIT_ID_WORK_EMAIL}" ]]; then
    echo "(work)"
  elif [[ "${email}" == "${GIT_ID_PERSONAL_EMAIL}" ]]; then
    echo "(personal)"
  else
    echo "(${email%%@*})"
  fi
}

_gitid_update_rprompt() {
  _gitid_emulate
  ((${GIT_ID_HIDE_PROMPT:-0} == 1)) && return 0
  local seg
  seg="$(_gitid_prompt_segment)" || true
  if [[ -n "${seg}" ]]; then
    if [[ -z "${GIT_ID_RPROMPT_BASE:-}" ]]; then
      GIT_ID_RPROMPT_BASE="${RPROMPT:-}"
    fi
    if [[ -n "${GIT_ID_RPROMPT_BASE}" ]]; then
      RPROMPT="${GIT_ID_RPROMPT_BASE} ${seg}"
    else
      RPROMPT="${seg}"
    fi
  else
    RPROMPT="${GIT_ID_RPROMPT_BASE}" # restore
  fi
}

autoload -Uz add-zsh-hook 2>/dev/null || true
add-zsh-hook chpwd _gitid_auto_maybe 2>/dev/null || true
add-zsh-hook precmd _gitid_update_rprompt 2>/dev/null || true

# Initial run
_gitid_auto_maybe
_gitid_update_rprompt

# Optional functions/ directory (if plugin managers don't handle it)
if [[ -d ${GitIdentityState[dir]}/functions ]]; then
  if { [[ -z ${PMSPEC:-} ]] || [[ $PMSPEC != *f* ]]; } \
     && [[ -z ${fpath[(r)${GitIdentityState[dir]}/functions]} ]]; then
    fpath+=( "${GitIdentityState[dir]}/functions" )
  fi
fi

# Unload function
git_identity_plugin_unload() {
  _gitid_emulate
  add-zsh-hook -d chpwd _gitid_auto_maybe 2>/dev/null || true
  add-zsh-hook -d precmd _gitid_update_rprompt 2>/dev/null || true
  [[ -n ${GIT_ID_RPROMPT_BASE:-} ]] && RPROMPT="${GIT_ID_RPROMPT_BASE}"
  unset 'GitIdentityState[loaded]' GIT_ID_RPROMPT_BASE
  _gitid_log "plugin unloaded"
  unfunction git_identity_plugin_unload 2>/dev/null || true
}

if typeset -f @zsh-plugin-run-on-unload &>/dev/null; then
  @zsh-plugin-run-on-unload 'git_identity_plugin_unload'
fi

_gitid_log "plugin loaded (auto=${GIT_IDENTITY_AUTO})"
