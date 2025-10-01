# --- git-identity.plugin.zsh (adapted for Pure / Powerlevel10k) ---

# --- Config (set these before loading) ---
: "${GIT_ID_PERSONAL_NAME:=Personal}"
: "${GIT_ID_PERSONAL_EMAIL:=personal@example.invalid}"
: "${GIT_ID_PERSONAL_KEY:=$HOME/.ssh/dpdd-github}"
: "${GIT_ID_WORK_NAME:=Work}"
: "${GIT_ID_WORK_EMAIL:=work@example.invalid}"
: "${GIT_ID_WORK_KEY:=$HOME/.ssh/id_rsa}"
: "${GIT_ID_AUTO_DEFAULT:=0}"
: "${GIT_ID_HIDE_PROMPT:=0}"
: "${GIT_ID_PROMPT_SIDE:=right}"  # left|right|both

# --- Helpers ---
_gitid_in_repo() { git rev-parse --is-inside-work-tree &>/dev/null; }

_gitid_detect_profile() {
  _gitid_in_repo || return 1
  local remote="$(git config --get remote.origin.url 2>/dev/null)"
  if [[ $PWD == */development/spend-cloud* || $remote == *Spend-Cloud* ]]; then
    echo work
  else
    echo personal
  fi
}

_gitid_apply_profile() {
  local profile=$1 name email key
  case $profile in
    personal) name=$GIT_ID_PERSONAL_NAME email=$GIT_ID_PERSONAL_EMAIL key=$GIT_ID_PERSONAL_KEY ;;
    work)     name=$GIT_ID_WORK_NAME     email=$GIT_ID_WORK_EMAIL     key=$GIT_ID_WORK_KEY ;;
    *) echo "git-identity: unknown profile: $profile" >&2; return 1 ;;
  esac
  [[ -f $key ]] || { echo "git-identity: key not found: $key" >&2; return 1; }
  git config user.name  "$name"
  git config user.email "$email"
  git config core.sshCommand "ssh -i $key"
}

_gitid_current_info() {
  _gitid_in_repo || { echo "Not a git repo" >&2; return 1; }
  printf "Name: %s\nEmail: %s\nSSH: %s\n" \
    "$(git config user.name)" \
    "$(git config user.email)" \
    "$(git config core.sshCommand)"
}

_gitid_auto() {
  (( GIT_ID_AUTO_DEFAULT )) || return 0
  _gitid_in_repo || return 0
  local want cur
  want="$(_gitid_detect_profile)" || return 0
  cur="$(git config user.email 2>/dev/null || echo '')"
  case $want in
    work) [[ $cur != "$GIT_ID_WORK_EMAIL" ]] && _gitid_apply_profile work ;;
    personal) [[ $cur != "$GIT_ID_PERSONAL_EMAIL" ]] && _gitid_apply_profile personal ;;
  esac
}

_gitid_prompt_segment() {
  (( GIT_ID_HIDE_PROMPT )) && return
  _gitid_in_repo || return
  local email="$(git config user.email 2>/dev/null)"
  [[ -z $email ]] && return
  local icon="👤"
  if [[ $email == "$GIT_ID_WORK_EMAIL" ]]; then
    echo "%F{103}(${icon} work)%f"
  elif [[ $email == "$GIT_ID_PERSONAL_EMAIL" ]]; then
    echo "%F{147}(${icon} personal)%f"
  fi
}

_gitid_update_rprompt() {
  [[ $GIT_ID_PROMPT_SIDE == left ]] && return
  local seg="$(_gitid_prompt_segment)" || return
  [[ -n $seg ]] && RPROMPT="$seg"
}

# --- Pure / Powerlevel10k Integration ---
_gitid_wrap_prompt_framework() {
  (( GIT_ID_HIDE_PROMPT )) && return

  # Pure left-side
  if typeset -f prompt_pure_preprompt_render &>/dev/null && [[ $GIT_ID_PROMPT_SIDE != right ]]; then
    if ! typeset -f _gitid_orig_pure_preprompt_render &>/dev/null; then
      eval "${$(functions prompt_pure_preprompt_render)/prompt_pure_preprompt_render/_gitid_orig_pure_preprompt_render}"
    fi
    prompt_pure_preprompt_render() {
      _gitid_orig_pure_preprompt_render "$@"
      local seg="$(_gitid_prompt_segment)" || return
      [[ -n $seg ]] && PROMPT="${seg} ${PROMPT}"
    }
  fi

  # Powerlevel10k segment
  if typeset -f p10k_segment_git_identity &>/dev/null; then
    return
  fi
  p10k_segment_git_identity() {
    _gitid_prompt_segment
  }
  # User should add `git_identity` to POWERLEVEL9K_LEFT/RIGHT_PROMPT_ELEMENTS
}

# --- Public CLI ---
git-identity() {
  local cmd=$1; shift
  case $cmd in
    show|status) _gitid_current_info ;;
    set) _gitid_apply_profile "$1" ;;
    auto) (( GIT_ID_AUTO_DEFAULT = !$GIT_ID_AUTO_DEFAULT )) ;;
    help|"") echo "git-identity {show|set <profile>|auto}" ;;
    *) echo "git-identity: unknown command $cmd" >&2 ;;
  esac
}

# --- Hooks ---
autoload -Uz add-zsh-hook
add-zsh-hook chpwd  _gitid_auto
add-zsh-hook precmd _gitid_update_rprompt
add-zsh-hook precmd _gitid_wrap_prompt_framework

# --- Initial run ---
_gitid_auto
_gitid_update_rprompt
_gitid_wrap_prompt_framework
