# --- git-identity.plugin.zsh (adapted for Pure / Powerlevel10k) ---

# --- Config (set these before loading) ---
: "${GIT_ID_PERSONAL_NAME:=dpdd}"
: "${GIT_ID_PERSONAL_EMAIL:=dpdd@squat.net}"
: "${GIT_ID_PERSONAL_KEY:=$HOME/.ssh/dpdd-github}"
: "${GIT_ID_WORK_NAME:=Tom}"
: "${GIT_ID_WORK_EMAIL:=tom.van.veen@visma.com}"
: "${GIT_ID_WORK_KEY:=$HOME/.ssh/id_rsa}"
: "${GIT_ID_AUTO_DEFAULT:=0}"
: "${GIT_ID_HIDE_PROMPT:=0}"
: "${GIT_ID_PROMPT_SIDE:=right}"  # left|right|both
: "${GIT_ID_SSH_CONFIG_PATH:=${HOME}/.ssh/config}"
: "${GIT_ID_PERSONAL_HOST:=github-personal}"
: "${GIT_ID_WORK_HOST:=github-work}"

typeset -g _GITID_PROMPT_BASE=""
typeset -g _GITID_RPROMPT_BASE=""
typeset -g _GITID_LAST_LSEGMENT=""
typeset -g _GITID_LAST_RSEGMENT=""
typeset -g _GITID_PURE_WRAPPED=0
typeset -g _GITID_ZLE_WRAPPED=0

# --- Helpers ---
_gitid_in_repo() { git rev-parse --is-inside-work-tree &>/dev/null; }

_gitid_host_for_profile() {
  local profile="$1"
  case $profile in
    personal) echo "$GIT_ID_PERSONAL_HOST" ;;
    work)     echo "$GIT_ID_WORK_HOST" ;;
    *)        echo "" ;;
  esac
}

_gitid_marker_begin() {
  echo "# git-identity:${1}:begin"
}

_gitid_marker_end() {
  echo "# git-identity:${1}:end"
}

_gitid_rewrite_remote_host() {
  local url="$1" target_host="$2"
  [[ -n $url && -n $target_host ]] || return 1

  if [[ $url == git@*:* ]]; then
    local host path
    host="${url#git@}"
    host="${host%%:*}"
    path="${url#git@${host}:}"
    printf 'git@%s:%s\n' "$target_host" "$path"
    return 0
  fi

  if [[ $url == ssh://* ]]; then
    local rest user host path
    rest="${url#ssh://}"
    if [[ $rest == *@*/* ]]; then
      user="${rest%%@*}"
      host="${rest#*@}"
      host="${host%%/*}"
      path="${rest#*@${host}/}"
      printf 'ssh://%s@%s/%s\n' "$user" "$target_host" "$path"
      return 0
    fi
  fi

  return 1
}

_gitid_update_remote_host() {
  local target_host="$1" remote_name="${2:-origin}"
  [[ -n $target_host ]] || return 1

  local fetch_url new_fetch
  fetch_url="$(git remote get-url "$remote_name" 2>/dev/null || true)"
  if [[ -n $fetch_url ]]; then
    new_fetch="$(_gitid_rewrite_remote_host "$fetch_url" "$target_host" 2>/dev/null || printf '')"
    if [[ -n $new_fetch && $new_fetch != "$fetch_url" ]]; then
      if ! git remote set-url "$remote_name" "$new_fetch"; then
        return 1
      fi
    fi
  fi

  local push_url new_push
  push_url="$(git remote get-url --push "$remote_name" 2>/dev/null || true)"
  if [[ -n $push_url && $push_url != "$fetch_url" ]]; then
    new_push="$(_gitid_rewrite_remote_host "$push_url" "$target_host" 2>/dev/null || printf '')"
    if [[ -n $new_push && $new_push != "$push_url" ]]; then
      if ! git remote set-url --push "$remote_name" "$new_push"; then
        return 1
      fi
    fi
  fi

  return 0
}

_gitid_ensure_ssh_host() {
  local profile="$1" host="$2" key="$3" config_path
  config_path="$GIT_ID_SSH_CONFIG_PATH"
  [[ -n $profile && -n $host && -n $key ]] || return 1

  local config_dir="${config_path:h}"
  command mkdir -p -- "$config_dir" || return 1
  [[ -f $config_path ]] || : >"$config_path"

  local begin end tmp
  begin="$(_gitid_marker_begin "$profile")"
  end="$(_gitid_marker_end "$profile")"
  tmp="$(command mktemp 2>/dev/null || true)"
  if [[ -z $tmp ]]; then
    tmp="${config_path}.tmp.$$"
  fi
  if [[ -n $tmp ]]; then
    command awk -v begin="$begin" -v end="$end" '
      $0 == begin {skip=1; next}
      $0 == end {skip=0; next}
      skip == 1 {next}
      {print}
    ' "$config_path" >"$tmp" 2>/dev/null && command mv -- "$tmp" "$config_path"
  fi

  if [[ -s $config_path ]]; then
    printf '\n' >>"$config_path"
  fi

  {
    printf '%s\n' "$begin"
    printf 'Host %s\n' "$host"
    printf '  HostName github.com\n'
    printf '  User git\n'
    printf '  IdentityFile %s\n' "$key"
    printf '  IdentitiesOnly yes\n'
    printf '%s\n' "$end"
  } >>"$config_path"

  command chmod 600 -- "$config_path" 2>/dev/null || true
}

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
  local profile=$1 name email key host config_path
  case $profile in
    personal) name=$GIT_ID_PERSONAL_NAME email=$GIT_ID_PERSONAL_EMAIL key=$GIT_ID_PERSONAL_KEY host=$(_gitid_host_for_profile personal) ;;
    work)     name=$GIT_ID_WORK_NAME     email=$GIT_ID_WORK_EMAIL     key=$GIT_ID_WORK_KEY host=$(_gitid_host_for_profile work) ;;
    *) echo "git-identity: unknown profile: $profile" >&2; return 1 ;;
  esac
  [[ -f $key ]] || { echo "git-identity: key not found: $key" >&2; return 1; }
  [[ -n $host ]] || { echo "git-identity: host alias missing for $profile" >&2; return 1; }

  _gitid_ensure_ssh_host "$profile" "$host" "$key" || {
    echo "git-identity: failed to update ssh config for $profile" >&2
    return 1
  }

  config_path="$GIT_ID_SSH_CONFIG_PATH"
  local ssh_cmd
  ssh_cmd=$(printf 'ssh -F %q -i %q -o IdentitiesOnly=yes' "$config_path" "$key")
  git config --local user.name  "$name"
  git config --local user.email "$email"
  git config --local core.sshCommand "$ssh_cmd"
  git config --local git-identity.profile "$profile"
  _gitid_update_remote_host "$host" || true
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

_gitid_refresh_prompt() {
  local seg=""
  if (( ! GIT_ID_HIDE_PROMPT )); then
    seg="$(_gitid_prompt_segment)" || seg=""
  fi

  local current_rprompt="$RPROMPT"
  if [[ -n $_GITID_LAST_RSEGMENT ]]; then
    case $current_rprompt in
      *" ${_GITID_LAST_RSEGMENT}")
        current_rprompt="${current_rprompt% "${_GITID_LAST_RSEGMENT}"}"
        ;;
      *"${_GITID_LAST_RSEGMENT}")
        current_rprompt="${current_rprompt%"${_GITID_LAST_RSEGMENT}"}"
        ;;
    esac
  fi

  if [[ $GIT_ID_PROMPT_SIDE == right || $GIT_ID_PROMPT_SIDE == both ]]; then
    _GITID_RPROMPT_BASE="$current_rprompt"
    if [[ -n $seg ]]; then
      if [[ -n $current_rprompt ]]; then
        RPROMPT="${current_rprompt} ${seg}"
      else
        RPROMPT="$seg"
      fi
      _GITID_LAST_RSEGMENT="$seg"
    else
      RPROMPT="$current_rprompt"
      _GITID_LAST_RSEGMENT=""
    fi
  else
    RPROMPT="$current_rprompt"
    _GITID_RPROMPT_BASE="$current_rprompt"
    _GITID_LAST_RSEGMENT=""
  fi

  local current_prompt="$PROMPT"
  if [[ -n $_GITID_LAST_LSEGMENT ]]; then
    case $current_prompt in
      "${_GITID_LAST_LSEGMENT} "*)
        current_prompt="${current_prompt#${_GITID_LAST_LSEGMENT} }"
        ;;
      "${_GITID_LAST_LSEGMENT}")
        current_prompt="${current_prompt#${_GITID_LAST_LSEGMENT}}"
        ;;
    esac
  fi

  if [[ $GIT_ID_PROMPT_SIDE == left || $GIT_ID_PROMPT_SIDE == both ]]; then
    _GITID_PROMPT_BASE="$current_prompt"
    if [[ -n $seg ]]; then
      if [[ -n $current_prompt ]]; then
        PROMPT="${seg} ${current_prompt}"
      else
        PROMPT="$seg"
      fi
      _GITID_LAST_LSEGMENT="$seg"
    else
      PROMPT="$current_prompt"
      _GITID_LAST_LSEGMENT=""
    fi
  else
    PROMPT="$current_prompt"
    _GITID_PROMPT_BASE="$current_prompt"
    _GITID_LAST_LSEGMENT=""
  fi
}

_gitid_zle_line_init() {
  if (( ${+functions[_gitid_orig_zle_line_init]} )); then
    _gitid_orig_zle_line_init "$@"
  fi
  _gitid_refresh_prompt
}

_gitid_wrap_zle() {
  (( _GITID_ZLE_WRAPPED )) && return
  (( GIT_ID_HIDE_PROMPT )) && return
  [[ $- == *i* ]] || return
  whence zle &>/dev/null || return

  if (( ${+functions[zle-line-init]} )); then
    functions[_gitid_orig_zle_line_init]=$functions[zle-line-init]
  fi

  zle -N zle-line-init _gitid_zle_line_init
  _GITID_ZLE_WRAPPED=1
}

_gitid_doctor() {
  _gitid_in_repo || { echo "git-identity doctor: not a git repo" >&2; return 1; }

  local remote base_host email sshcmd key profile detection
  remote="$(git remote get-url --push origin 2>/dev/null || git remote get-url origin 2>/dev/null || echo '(no remote)')"
  email="$(git config user.email 2>/dev/null || echo '(unset)')"
  sshcmd="$(git config core.sshCommand 2>/dev/null || echo '(unset)')"
  profile="$(git config git-identity.profile 2>/dev/null || echo '(unknown)')"
  detection="$(_gitid_detect_profile 2>/dev/null || echo '-')"

  if [[ $remote == git@*:* ]]; then
    base_host="${remote#*@}"
    base_host="${base_host%%:*}"
  else
    base_host="(unknown)"
  fi

  if [[ $sshcmd == *" -i "* ]]; then
    key="${sshcmd#*-i }"
    key="${key%% *}"
  else
    key="(not set)"
  fi

  local resolved_profile host_alias host_entry='missing' config_path="$GIT_ID_SSH_CONFIG_PATH"
  case $profile in
    personal|work) resolved_profile="$profile" ;;
    *) resolved_profile="$detection" ;;
  esac

  if [[ -n $resolved_profile && $resolved_profile != '-' ]]; then
    host_alias="$(_gitid_host_for_profile "$resolved_profile")"
    if [[ -n $host_alias && -f $config_path ]]; then
      local begin_marker
      begin_marker="$(_gitid_marker_begin "$resolved_profile")"
      if command grep -Fq "$begin_marker" "$config_path" 2>/dev/null; then
        host_entry='present'
      fi
    elif [[ -z $host_alias ]]; then
      host_entry='skipped'
    fi
  else
    host_alias=''
    host_entry='skipped'
  fi

  printf 'git-identity doctor\n'
  printf '  Repo:      %s\n' "$PWD"
  printf '  Remote:    %s\n' "$remote"
  printf '  Host:      %s\n' "$base_host"
  printf '  Email:     %s\n' "$email"
  printf '  Profile:   %s\n' "$profile"
  printf '  Detected:  %s\n' "$detection"
  printf '  Host Alias:%s\n' " ${host_alias:-n/a}"
  printf '  SSH Config:%s (%s)\n' " ${config_path}" "$host_entry"
  printf '  SSH Cmd:   %s\n' "$sshcmd"
  printf '  Key Path:  %s\n' "$key"

  if [[ -f $key && $base_host != '(unknown)' ]]; then
    local ssh_output ssh_status
    ssh_output="$(command ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$key" "git@${base_host}" -T 2>&1 </dev/null)"
    ssh_status=$?
    printf '  SSH Test:  exit=%d\n' "$ssh_status"
    printf '             %s\n' "${ssh_output:-<no output>}"
  else
    printf '  SSH Test:  skipped (missing key or host)\n'
  fi
}

# --- Pure / Powerlevel10k Integration ---
_gitid_wrap_prompt_framework() {
  (( GIT_ID_HIDE_PROMPT )) && return

  # Pure left-side
  if typeset -f prompt_pure_preprompt_render &>/dev/null \
     && [[ $GIT_ID_PROMPT_SIDE != right ]] \
     && (( !_GITID_PURE_WRAPPED )); then
    if ! typeset -f _gitid_orig_pure_preprompt_render &>/dev/null; then
      if (( ${+functions[prompt_pure_preprompt_render]} )); then
        functions[_gitid_orig_pure_preprompt_render]=$functions[prompt_pure_preprompt_render]
      else
        return
      fi
    fi
    prompt_pure_preprompt_render() {
      _gitid_orig_pure_preprompt_render "$@"
      _gitid_refresh_prompt
    }
    _GITID_PURE_WRAPPED=1
  fi

  # Powerlevel10k segment
  if ! typeset -f p10k_segment_git_identity &>/dev/null; then
    p10k_segment_git_identity() {
      _gitid_prompt_segment
    }
  fi
  # User should add `git_identity` to POWERLEVEL9K_LEFT/RIGHT_PROMPT_ELEMENTS

  _gitid_wrap_zle
}

# --- Public CLI ---
git-identity() {
  local cmd=$1; shift
  case $cmd in
    show|status) _gitid_current_info ;;
    set) _gitid_apply_profile "$1" ;;
    auto) (( GIT_ID_AUTO_DEFAULT = !$GIT_ID_AUTO_DEFAULT )) ;;
    doctor) _gitid_doctor ;;
  help|"") echo "git-identity {show|set <profile>|auto|doctor}" ;;
    *) echo "git-identity: unknown command $cmd" >&2 ;;
  esac
}

# --- Hooks ---
autoload -Uz add-zsh-hook
add-zsh-hook chpwd  _gitid_auto
add-zsh-hook precmd _gitid_refresh_prompt
add-zsh-hook precmd _gitid_wrap_prompt_framework

# --- Initial run ---
_gitid_auto
_gitid_refresh_prompt
_gitid_wrap_prompt_framework
