#!/bin/bash
# Logging & messaging utilities.

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
