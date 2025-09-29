#!/usr/bin/env bash
# Logging & messaging utilities.
set -Eeuo pipefail

_ts() { date '+%H:%M:%S'; }
_log() { printf '%s %s\n' "$(_ts)" "$*" >>"$LOG_FILE"; }
log() { _log "INFO: $*"; }
note() { printf "%b•%b %s%b\n" "$C_DIM" "$C_RESET" "$*" "$C_RESET"; _log "NOTE: $*"; }
info() { printf "%bℹ%b %s%b\n" "$C_CYAN" "$C_RESET" "$*" "$C_RESET"; _log "INFO: $*"; }
step() { printf "%b▶%b %s%b\n" "$C_BLUE" "$C_RESET" "$*" "$C_RESET"; _log "STEP: $*"; }
success() { printf "%b✔%b %s%b\n" "$C_GREEN" "$C_RESET" "$*" "$C_RESET"; _log "OK: $*"; }
warn() { printf "%b!%b %s%b\n" "$C_YELLOW" "$C_RESET" "$*" "$C_RESET" >&2; _log "WARN: $*"; }
error() { printf "%b✖%b %s%b\n" "$C_RED" "$C_RESET" "$*" "$C_RESET" >&2; _log "ERR: $*"; }
headline() { local msg="$1"; printf "\n%b%s%b %b%s%b\n" "$C_MAGENTA" "────────" "$C_RESET" "$C_BOLD" "$msg" "$C_RESET"; _log "HEAD: $msg"; }
die() { error "$1"; exit 1; }
