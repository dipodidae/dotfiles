#!/usr/bin/env zsh
#
# remote-prepare plugin: clone the dotfiles repository onto a remote host
# and execute the installer, optionally streaming the remote install log.

# Allow re-sourcing (overwrite existing definitions)
typeset -g _REMOTE_PREPARE_PLUGIN_LOADED=1

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  typeset -g _REMOTE_PREPARE_COLOR_RESET=$'\033[0m'
  typeset -g _REMOTE_PREPARE_COLOR_DIM=$'\033[2m'
  typeset -g _REMOTE_PREPARE_COLOR_INFO=$'\033[38;5;39m'
  typeset -g _REMOTE_PREPARE_COLOR_WARN=$'\033[38;5;214m'
  typeset -g _REMOTE_PREPARE_COLOR_SUCCESS=$'\033[38;5;46m'
else
  typeset -g _REMOTE_PREPARE_COLOR_RESET=""
  typeset -g _REMOTE_PREPARE_COLOR_DIM=""
  typeset -g _REMOTE_PREPARE_COLOR_INFO=""
  typeset -g _REMOTE_PREPARE_COLOR_WARN=""
  typeset -g _REMOTE_PREPARE_COLOR_SUCCESS=""
fi

typeset -g _REMOTE_PREPARE_DEFAULT_REPO='https://github.com/dipodidae/dotfiles.git'

typeset -gU _REMOTE_PREPARE_LAST_REMOTE=

# ────────────────────────────────────────────────────────────────────────────────
# LOGGING HELPERS
# ────────────────────────────────────────────────────────────────────────────────

_remote_prepare_plugin::log_info() {
  printf '%sℹ️ %s%s\n' "${_REMOTE_PREPARE_COLOR_INFO}" "$*" "${_REMOTE_PREPARE_COLOR_RESET}"
}

_remote_prepare_plugin::log_success() {
  printf '%s✅ %s%s\n' "${_REMOTE_PREPARE_COLOR_SUCCESS}" "$*" "${_REMOTE_PREPARE_COLOR_RESET}"
}

_remote_prepare_plugin::log_warn() {
  printf '%s⚠️ %s%s\n' "${_REMOTE_PREPARE_COLOR_WARN}" "$*" "${_REMOTE_PREPARE_COLOR_RESET}" >&2
}

_remote_prepare_plugin::log_error() {
  printf '%s❌ %s%s\n' "${_REMOTE_PREPARE_COLOR_WARN}" "$*" "${_REMOTE_PREPARE_COLOR_RESET}" >&2
}

#######################################
# _remote_prepare_plugin::usage
# Print usage help text for prepare-remote command.
# Returns:
#   0 always.
#######################################
_remote_prepare_plugin::usage() {
  cat << 'EOF'
Usage: prepare-remote <user@host> [options] [-- <install args>]
Options:
  -p, --port <port>       SSH port (default: 22)
      --repo <url>        Dotfiles repository URL (default: origin of current clone or upstream)
      --branch <branch>   Git branch to deploy (default: current branch or "main")
      --target <path>     Install directory on remote (default: ~/.dotfiles)
      --logs              Show the tail of ~/.dotfiles-install.log after install
  -h, --help              Display this help message

Examples:
  prepare-remote tom@example.com
  prepare-remote tom@example.com --branch develop --logs -- --skip-packages
EOF
}

#######################################
# Build the SSH command array used for remote execution.
# Arguments:
#   1 - Name of the array variable to populate.
#   2 - Remote destination (user@host).
#   3 - SSH port.
#######################################
_remote_prepare_plugin::build_ssh_cmd() {
  emulate -L zsh
  setopt local_options pipefail
  local out_name="$1" remote="$2" port="$3"
  local -a assembled=(ssh -o BatchMode=no)

  ((port != 22)) && assembled+=(-p "${port}")
  assembled+=("${remote}")

  local -n out_ref="${out_name}"
  out_ref=("${assembled[@]}")
}

#######################################
# Execute a command on the remote host over SSH.
# Arguments:
#   1 - Remote destination (user@host).
#   2 - SSH port.
#   3+ - Command and arguments to run remotely.
# Returns:
#   Status code from the ssh invocation.
#######################################
_remote_prepare_plugin::remote_exec() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" port="$2"
  shift 2
  local -a ssh_cmd

  _remote_prepare_plugin::build_ssh_cmd ssh_cmd "${remote}" "${port}"

  if (($# == 0)); then
    "${ssh_cmd[@]}"
    return $?
  fi

  if [[ "$1" == "sh" || "$1" == "bash" ]]; then
    local shell="$1"
    local flag="${2:-}"
    if [[ "${flag}" == "-c" || "${flag}" == "-lc" ]]; then
      if (($# < 3)); then
        _remote_prepare_plugin::log_error "remote_exec missing script for ${shell} ${flag}"
        return 1
      fi
      local remote_script="$3"
      shift 3
      if (($# > 0)); then
        print -r -- "${remote_script}" | "${ssh_cmd[@]}" "${shell}" -s -- "$@"
      else
        print -r -- "${remote_script}" | "${ssh_cmd[@]}" "${shell}" -s
      fi
      return $?
    fi
  fi

  "${ssh_cmd[@]}" "$@"
  return $?
}

#######################################
# Attempt to detect repository URL from local git clone.
# Outputs:
#   Detected URL or empty string.
#######################################
_remote_prepare_plugin::detect_repo() {
  emulate -L zsh
  setopt local_options pipefail
  if ! command -v git > /dev/null 2>&1; then
    printf ''
    return 0
  fi
  if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
    printf ''
    return 0
  fi
  local origin
  origin="$(git config --get remote.origin.url 2> /dev/null)"
  printf '%s' "${origin}"
}

#######################################
# Attempt to detect current git branch from local clone.
# Outputs:
#   Branch name or empty string.
#######################################
_remote_prepare_plugin::detect_branch() {
  emulate -L zsh
  setopt local_options pipefail
  if ! command -v git > /dev/null 2>&1; then
    printf ''
    return 0
  fi
  if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
    printf ''
    return 0
  fi
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
  if [[ "${branch}" == "HEAD" ]]; then
    printf ''
    return 0
  fi
  printf '%s' "${branch}"
}

#######################################
# Render a quick summary block for the pending remote install.
# Arguments:
#   1 - Remote (user@host)
#   2 - Repository URL
#   3 - Branch
#   4 - Target directory
#######################################
_remote_prepare_plugin::print_summary() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" repo="$2" branch="$3" target="$4"

  printf '%sPreparing remote install%s\n' "${_REMOTE_PREPARE_COLOR_INFO}" "${_REMOTE_PREPARE_COLOR_RESET}"
  printf '%s  Remote:%s %s\n' "${_REMOTE_PREPARE_COLOR_DIM}" "${_REMOTE_PREPARE_COLOR_RESET}" "${remote}"
  printf '%s  Repo:%s   %s\n' "${_REMOTE_PREPARE_COLOR_DIM}" "${_REMOTE_PREPARE_COLOR_RESET}" "${repo}"
  printf '%s  Branch:%s %s\n' "${_REMOTE_PREPARE_COLOR_DIM}" "${_REMOTE_PREPARE_COLOR_RESET}" "${branch}"
  printf '%s  Target:%s %s\n' "${_REMOTE_PREPARE_COLOR_DIM}" "${_REMOTE_PREPARE_COLOR_RESET}" "${target}"
}

#######################################
# Copy dotfiles repo and run installer on remote host.
# Arguments:
#   * - Remote destination and options (see usage).
# Returns:
#   0 on success, non-zero on failure.
#######################################
prepare_remote() {
  emulate -L zsh
  setopt local_options pipefail

  local port=22 show_logs=0
  local repo_override=0 branch_override=0
  local repo="${_REMOTE_PREPARE_DEFAULT_REPO}"
  local branch="main"
  local target='~/.dotfiles'
  local remote=""
  local -a install_args

  while (($#)); do
    case "$1" in
      -p | --port)
        if [[ -n "${2:-}" ]]; then
          port="$2"
          shift 2
          continue
        fi
        _remote_prepare_plugin::log_error "Missing value for $1"
        return 2
        ;;
      --repo)
        if [[ -n "${2:-}" ]]; then
          repo="$2"
          repo_override=1
          shift 2
          continue
        fi
        _remote_prepare_plugin::log_error "Missing value for --repo"
        return 2
        ;;
      --branch)
        if [[ -n "${2:-}" ]]; then
          branch="$2"
          branch_override=1
          shift 2
          continue
        fi
        _remote_prepare_plugin::log_error "Missing value for --branch"
        return 2
        ;;
      --target | --path)
        if [[ -n "${2:-}" ]]; then
          target="$2"
          shift 2
          continue
        fi
        _remote_prepare_plugin::log_error "Missing value for $1"
        return 2
        ;;
      --logs)
        show_logs=1
        shift
        continue
        ;;
      -h | --help)
        _remote_prepare_plugin::usage
        return 0
        ;;
      --)
        shift
        install_args=("$@")
        break
        ;;
      -*)
        _remote_prepare_plugin::log_error "Unknown option: $1"
        _remote_prepare_plugin::usage >&2
        return 2
        ;;
      *)
        if [[ -z "${remote}" ]]; then
          remote="$1"
        else
          install_args+=("$1")
        fi
        shift
        ;;
    esac
  done

  if [[ -z "${remote}" ]]; then
    _remote_prepare_plugin::usage >&2
    return 2
  fi

  if ((repo_override == 0)); then
    local detected_repo
    detected_repo="$(_remote_prepare_plugin::detect_repo)"
    [[ -n "${detected_repo}" ]] && repo="${detected_repo}"
  fi

  if ((branch_override == 0)); then
    local detected_branch
    detected_branch="$(_remote_prepare_plugin::detect_branch)"
    [[ -n "${detected_branch}" ]] && branch="${detected_branch}"
  fi

  if ! command -v ssh > /dev/null 2>&1; then
    _remote_prepare_plugin::log_error "ssh command not found on local machine"
    return 127
  fi

  if [[ "${remote}" != *"@"* ]]; then
    _remote_prepare_plugin::log_warn "Remote should include user (example: user@host)"
  fi

  _REMOTE_PREPARE_LAST_REMOTE="${remote}"
  _remote_prepare_plugin::print_summary "${remote}" "${repo}" "${branch}" "${target}"

  if ! _remote_prepare_plugin::remote_exec "${remote}" "${port}" sh -c 'command -v git >/dev/null 2>&1'; then
    _remote_prepare_plugin::log_error "git is required on the remote host"
    return 1
  fi

  local remote_script
  remote_script=$(
    cat << 'EOF'
set -eu
repo="$1"
branch="$2"
target="$3"
shift 3
case "$target" in
  "~")
    target="$HOME"
    ;;
  ~/*)
    target="$HOME/${target#~/}"
    ;;
  *)
    target="$target"
    ;;
esac
if ! command -v git >/dev/null 2>&1; then
  echo "[prepare-remote] git is required on the remote host." >&2
  exit 101
fi
parent_dir="$(dirname "$target")"
mkdir -p "$parent_dir"
if [ -d "$target/.git" ]; then
  git -C "$target" fetch origin --tags --prune
  if git -C "$target" rev-parse --verify "refs/heads/$branch" >/dev/null 2>&1; then
    git -C "$target" checkout "$branch"
  else
    git -C "$target" checkout -B "$branch" "origin/$branch"
  fi
  git -C "$target" reset --hard "origin/$branch"
else
  if [ -d "$target" ] && [ -z "$(ls -A "$target" 2>/dev/null)" ]; then
    rmdir "$target" || true
  fi
  if [ -d "$target" ] && [ "$(ls -A "$target" 2>/dev/null)" ]; then
    echo "[prepare-remote] Target directory $target is not empty." >&2
    exit 102
  fi
  git clone --depth 1 --branch "$branch" "$repo" "$target"
fi
cd "$target"
if [ ! -x install.sh ]; then
  chmod +x install.sh || true
fi
./install.sh "$@"
EOF
  )

  _remote_prepare_plugin::log_info "Running remote installer..."
  if ! _remote_prepare_plugin::remote_exec "${remote}" "${port}" sh -s -- "${repo}" "${branch}" "${target}" "${install_args[@]}" <<< "${remote_script}"; then
    _remote_prepare_plugin::log_error "Remote install failed"
    show_logs=1
    _remote_prepare_plugin::show_remote_logs "${remote}" "${port}"
    return 1
  fi

  _remote_prepare_plugin::log_success "Remote install complete"
  _remote_prepare_plugin::log_info "Remote log: ~/.dotfiles-install.log"

  if ((show_logs)); then
    _remote_prepare_plugin::show_remote_logs "${remote}" "${port}"
  fi

  return 0
}

#######################################
# Fetch and display the tail of the remote install log.
# Arguments:
#   1 - Remote destination (user@host)
#   2 - SSH port
#######################################
_remote_prepare_plugin::show_remote_logs() {
  emulate -L zsh
  setopt local_options pipefail
  local remote="$1" port="$2"
  local log_cmd='if [ -f "$HOME/.dotfiles-install.log" ]; then tail -n 60 "$HOME/.dotfiles-install.log"; else echo "[prepare-remote] Remote install log not found" >&2; fi'
  _remote_prepare_plugin::log_info "Remote install log preview"
  _remote_prepare_plugin::remote_exec "${remote}" "${port}" sh -c "${log_cmd}"
}

alias prepare-remote='prepare_remote'
