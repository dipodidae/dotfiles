#!/bin/bash
# Logging & messaging utilities.

# Initialize color constants if not already set (for standalone module usage)
if [[ -z "${C_RESET:-}" ]]; then
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    readonly C_RESET='\033[0m'
    readonly C_DIM='\033[2m'
    readonly C_RED='\033[31m'
    readonly C_GREEN='\033[32m'
    readonly C_YELLOW='\033[33m'
    readonly C_BLUE='\033[34m'
    readonly C_MAGENTA='\033[35m'
    readonly C_CYAN='\033[36m'
    readonly C_BOLD='\033[1m'
  else
    readonly C_RESET=""
    readonly C_DIM=""
    readonly C_RED=""
    readonly C_GREEN=""
    readonly C_YELLOW=""
    readonly C_BLUE=""
    readonly C_MAGENTA=""
    readonly C_CYAN=""
    readonly C_BOLD=""
  fi
fi

# Initialize LOG_FILE if not already set (for standalone module usage)
if [[ -z "${LOG_FILE:-}" ]]; then
  LOG_FILE="${HOME}/.dotfiles-install.log"
fi

#######################################
# _ts
# Prints a compact timestamp (HH:MM:SS) for log prefixing.
# Globals: none
# Outputs: timestamp string to STDOUT
#######################################
_ts() { date '+%H:%M:%S'; }

#######################################
# _log
# Append a raw log line (already severity-prefixed) to $LOG_FILE.
# Globals: LOG_FILE
# Arguments: remaining words form the message
# Outputs: none (writes to file)
#######################################
_log() { printf '%s %s\n' "$(_ts)" "$*" >> "$LOG_FILE"; }

#######################################
# log
# Convenience info-level logger (INFO: prefix)
# Arguments: message words
#######################################
log() { _log "INFO: $*"; }

#######################################
# note
# Dim bullet note (non-critical info) + file log NOTE:
#######################################
note() {
  printf "%b•%b %s%b\n" "$C_DIM" "$C_RESET" "$*" "$C_RESET"
  _log "NOTE: $*"
}

#######################################
# info
# Cyan info message + file log INFO:
#######################################
info() {
  printf "%bℹ%b %s%b\n" "$C_CYAN" "$C_RESET" "$*" "$C_RESET"
  _log "INFO: $*"
}

#######################################
# step
# Blue progress step indicator + file log STEP:
#######################################
step() {
  printf "%b▶%b %s%b\n" "$C_BLUE" "$C_RESET" "$*" "$C_RESET"
  _log "STEP: $*"
}

#######################################
# success
# Green success check mark + file log OK:
#######################################
success() {
  printf "%b✔%b %s%b\n" "$C_GREEN" "$C_RESET" "$*" "$C_RESET"
  _log "OK: $*"
}

#######################################
# warn
# Yellow warning emitted to STDERR + file log WARN:
#######################################
warn() {
  printf "%b!%b %s%b\n" "$C_YELLOW" "$C_RESET" "$*" "$C_RESET" >&2
  _log "WARN: $*"
}

#######################################
# error
# Red error marker to STDERR + file log ERR:
#######################################
error() {
  printf "%b✖%b %s%b\n" "$C_RED" "$C_RESET" "$*" "$C_RESET" >&2
  _log "ERR: $*"
}

#######################################
# headline
# Section headline with visual divider + file log HEAD:
#######################################
headline() {
  local msg="$1"
  printf "\n%b%s%b %b%s%b\n" "$C_MAGENTA" "────────" "$C_RESET" "$C_BOLD" "$msg" "$C_RESET"
  _log "HEAD: $msg"
}

#######################################
# die
# Log an error and exit non-zero.
# Arguments: $1 reason text
# Exits: 1
#######################################
die() {
  error "$1"
  exit 1
}
