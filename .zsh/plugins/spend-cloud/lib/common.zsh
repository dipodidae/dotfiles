#!/usr/bin/env zsh
#
# Common utilities and constants for SpendCloud plugin.

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS & CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Color codes (TTY-aware)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly C_RED=$'\033[0;31m' C_GREEN=$'\033[0;32m' C_YELLOW=$'\033[1;33m'
  readonly C_BLUE=$'\033[0;34m' C_PURPLE=$'\033[0;35m' C_CYAN=$'\033[0;36m'
  readonly C_WHITE=$'\033[1;37m' C_RESET=$'\033[0m'
else
  readonly C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_PURPLE="" C_CYAN="" C_WHITE="" C_RESET=""
fi

# SpendCloud specific configuration
readonly SC_DEV_CONTAINER_PATTERN='(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)'
readonly SC_API_CONTAINER_PATTERN='spend.*cloud.*api|api.*spend.*cloud'
readonly SC_DEV_LOG_DIR="${HOME}/.cache/spend-cloud/logs"
readonly SC_API_DIR="${HOME}/development/spend-cloud/api"
readonly SC_PROACTIVE_DIR="${HOME}/development/proactive-frame"

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS (Reusable across commands)
# ═══════════════════════════════════════════════════════════════════════════════

#######################################
# Print colored output with automatic reset.
# Arguments:
#   1 - Color code (C_RED, C_GREEN, etc.)
#   2 - Message text
# Outputs:
#   Writes colored message to stdout
#######################################
_sc_print() { echo -e "${1}${2}${C_RESET}"; }

#######################################
# Print error message in red with error emoji.
# Arguments:
#   * - Message text
# Outputs:
#   Writes error message to stdout
#######################################
_sc_error() { _sc_print "${C_RED}" "❌ ${*}"; }

#######################################
# Print success message in green with checkmark emoji.
# Arguments:
#   * - Message text
# Outputs:
#   Writes success message to stdout
#######################################
_sc_success() { _sc_print "${C_GREEN}" "✅ ${*}"; }

#######################################
# Print warning message in yellow with warning emoji.
# Arguments:
#   * - Message text
# Outputs:
#   Writes warning message to stdout
#######################################
_sc_warn() { _sc_print "${C_YELLOW}" "⚠️  ${*}"; }

#######################################
# Print info message in cyan.
# Arguments:
#   * - Message text
# Outputs:
#   Writes info message to stdout
#######################################
_sc_info() { _sc_print "${C_CYAN}" "${*}"; }

#######################################
# Verify that a required command exists on PATH.
# Arguments:
#   1 - Command name to check
#   2 - Optional custom error message
# Outputs:
#   Error message to stdout if command not found
# Returns:
#   0 if command exists, 1 otherwise
#######################################
_sc_require_command() {
  command -v "${1}" >/dev/null 2>&1 || {
    _sc_error "'${1}' command not found. ${2:-Install it and try again.}"
    return 1
  }
}

#######################################
# Find first running container matching a pattern.
# Arguments:
#   1 - Regex pattern to match container names
# Outputs:
#   Container name to stdout if found
# Returns:
#   0 always (empty output if no match)
#######################################
_sc_find_container() {
  docker ps --format '{{.Names}}' | grep -E "${1}" | head -1
}
