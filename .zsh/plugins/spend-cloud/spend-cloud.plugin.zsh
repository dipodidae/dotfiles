#!/usr/bin/env zsh
#
# SpendCloud / Proactive Frame / Cluster tooling plugin for zsh.
# A proper oh-my-zsh compatible plugin.
#
# Usage:
#   Add 'spend-cloud' to your plugins array in ~/.zshrc:
#   plugins=(git zsh-autosuggestions ... spend-cloud)
#
#   To disable, simply comment it out or remove from plugins array.
#
# Exposed user-facing commands / aliases (PUBLIC API):
#   Aliases: sc scapi scui cui capi devapi pf cpf
#   Functions: cluster migrate nuke
#
# Refactored using clean code principles: DRY, SRP, meaningful names, small functions.

# Guard against duplicate loading
if [[ -n "${_SPEND_CLOUD_PLUGIN_LOADED:-}" ]]; then
  return 0
fi
readonly _SPEND_CLOUD_PLUGIN_LOADED=1


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
  command -v "${1}" > /dev/null 2>&1 || {
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

# ═══════════════════════════════════════════════════════════════════════════════
# DOCKER CONTAINER MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

#######################################
# List all SpendCloud dev/cluster containers.
# Globals:
#   SC_DEV_CONTAINER_PATTERN
# Outputs:
#   Container names (one per line) to stdout
# Returns:
#   0 always (empty if no containers)
#######################################
_sc_list_dev_containers() {
  docker ps -a --format "{{.Names}}" | grep -E "${SC_DEV_CONTAINER_PATTERN}" 2> /dev/null || true
}

#######################################
# Stop and remove containers from stdin list.
# Inputs:
#   Container names from stdin (one per line)
# Outputs:
#   None (errors suppressed)
# Returns:
#   0 always
#######################################
_sc_stop_and_remove_containers() {
  local names
  names="$(cat)"
  [[ -z "${names}" ]] && return 0
  echo "${names}" | xargs -r docker stop 2> /dev/null || true
  echo "${names}" | xargs -r docker rm 2> /dev/null || true
}

#######################################
# Clean up any existing dev containers before cluster start.
# Outputs:
#   Status messages to stdout
# Returns:
#   0 always
#######################################
_sc_cleanup_existing_containers() {
  _sc_info "🔍 Checking for existing containers..."
  local containers
  containers="$(_sc_list_dev_containers | head -15)"

  if [[ -z "${containers}" ]]; then
    _sc_success "No conflicting containers found"
    return 0
  fi

  _sc_warn "Found existing containers that may conflict:"
  while IFS= read -r container; do
    echo "  • ${container}"
  done <<< "${containers}"

  _sc_warn "🛑 Stopping and removing containers..."
  printf '%s' "${containers}" | _sc_stop_and_remove_containers
  _sc_success "Containers stopped and removed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEV SERVICE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

#######################################
# Start a dev service in background.
# Arguments:
#   1 - Service directory path
#   2 - Log file prefix
#   3 - Color code for status message
# Globals:
#   SC_DEV_LOG_DIR
# Outputs:
#   Status messages to stdout
# Returns:
#   0 on success, 1 on failure
#######################################
_sc_start_dev_service() {
  local service_dir="${1}" log_prefix="${2}" color="${3}"

  if [[ ! -d "${service_dir}" ]]; then
    _sc_warn "Skipping dev start: directory not found (${service_dir})"
    return 0
  fi

  _sc_print "${color}" "⚡ Starting dev for ${log_prefix}..."
  mkdir -p "${SC_DEV_LOG_DIR}"

  (
    cd "${service_dir}" || exit 1
    nohup sct dev >> "${SC_DEV_LOG_DIR}/${log_prefix}.log" 2>&1 &
  ) || {
    _sc_error "Failed to start dev in ${service_dir}"
    return 1
  }
}

#######################################
# Start all SpendCloud dev services in background.
# Globals:
#   SC_API_DIR
#   SC_PROACTIVE_DIR
#   SC_DEV_LOG_DIR
# Outputs:
#   Status messages to stdout
# Returns:
#   0 if all services started, 1 if any failed
#######################################
_sc_start_all_dev_services() {
  sleep 2
  local fail=0

  _sc_start_dev_service "${SC_API_DIR}" "spend-cloud-api" "${C_PURPLE}" || fail=1
  _sc_start_dev_service "${SC_PROACTIVE_DIR}" "proactive-frame" "${C_CYAN}" || fail=1

  if ((fail == 0)); then
    _sc_success "All services started!"
    _sc_print "${C_WHITE}" "🌟 SCT cluster + dev services running in background."
    return 0
  fi

  _sc_warn "Cluster started, but some dev services failed. Check logs in ${SC_DEV_LOG_DIR}."
  return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# PROJECT NAVIGATION ALIASES
# ═══════════════════════════════════════════════════════════════════════════════

alias sc='cd ~/development/spend-cloud'
alias scapi='sc && cd api'
alias scui='sc && cd ui'
alias cui='code ~/development/spend-cloud/ui'
alias capi='code ~/development/spend-cloud/api'
alias devapi='scapi && sct dev'
alias pf='cd ~/development/proactive-frame'
alias cpf='code ~/development/proactive-frame'

# ═══════════════════════════════════════════════════════════════════════════════
# CLUSTER COMMAND
# ═══════════════════════════════════════════════════════════════════════════════

#######################################
# Stop all cluster and dev containers.
# Outputs:
#   Status messages to stdout
# Returns:
#   0 always
#######################################
_cluster_stop() {
  _sc_warn "🛑 Stopping all cluster services..."
  _sc_info "🔍 Stopping and removing all containers..."

  local containers
  containers="$(_sc_list_dev_containers)"
  [[ -n "${containers}" ]] && {
    printf '%s' "${containers}" | _sc_stop_and_remove_containers
    _sc_success "Containers stopped and removed"
  }

  _sc_print "${C_BLUE}" "🛑 Stopping SCT cluster..."
  sct cluster stop
  _sc_success "Cluster stopped successfully"
}

#######################################
# Show cluster service logs.
# Arguments:
#   1 - Optional service name (all services if empty)
# Outputs:
#   Logs to stdout via sct
# Returns:
#   0 always
#######################################
_cluster_logs() {
  local service="${1}"
  if [[ -n "${service}" ]]; then
    _sc_info "📋 Showing logs for service: ${service}"
    sct cluster logs "${service}"
  else
    _sc_info "📋 Showing logs for all cluster services..."
    sct cluster logs
  fi
}

#######################################
# Start cluster and dev services.
# Arguments:
#   1 - Optional "rebuild" flag for fresh images
# Outputs:
#   Status messages to stdout
# Returns:
#   0 on success, 1 on cluster start failure
#######################################
_cluster_start() {
  local rebuild="${1}"

  _sc_cleanup_existing_containers

  if [[ "${rebuild}" == "rebuild" ]]; then
    _sc_warn "🔄 Rebuilding cluster with fresh images..."
    _sc_print "${C_BLUE}" "🚀 Starting SCT cluster..."
    sct cluster start --build --pull || {
      _sc_error "Failed to start SCT cluster. Aborting..."
      return 1
    }
  else
    _sc_print "${C_BLUE}" "🚀 Starting SCT cluster..."
    sct cluster start || {
      _sc_error "Failed to start SCT cluster. Aborting..."
      return 1
    }
  fi

  _sc_start_all_dev_services
}

#######################################
# Display cluster command usage.
# Outputs:
#   Help text to stdout
#######################################
_cluster_help() {
  cat << 'EOF'
SpendCloud Cluster Management
Usage: cluster [--rebuild|stop|logs [service]|help]
  (no args)       Start cluster and dev services (api + proactive frame)
  --rebuild       Rebuild and start cluster with fresh images
  stop            Stop all cluster and dev services
  logs [service]  Show logs (all or specific)
  help            Show this message
EOF
}

#######################################
# Manage SpendCloud cluster lifecycle.
# Arguments:
#   1 - Command: stop|logs|help|--rebuild|start (default)
#   2+ - Additional arguments (e.g., service name for logs)
# Outputs:
#   Status messages and logs to stdout
# Returns:
#   0 on success, 1 on failure
#######################################
cluster() {
  _sc_require_command sct "Install the SpendCloud CLI (sct)" || return 1

  case "${1:-start}" in
    stop) _cluster_stop ;;
    logs) _cluster_logs "${2}" ;;
    help | -h | --help) _cluster_help ;;
    --rebuild) _cluster_start "rebuild" ;;
    start | *) _cluster_start ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# MIGRATE COMMAND
# ═══════════════════════════════════════════════════════════════════════════════

#######################################
# Get running API container name.
# Globals:
#   SC_API_CONTAINER_PATTERN
# Outputs:
#   Container name to stdout
#   Error message to stderr if not found
# Returns:
#   0 if found, 1 otherwise
#######################################
_migrate_get_container() {
  _sc_find_container "${SC_API_CONTAINER_PATTERN}" || {
    echo "API container not found. Start with 'cluster'." >&2
    return 1
  }
}

#######################################
# Get migration group order.
# Globals:
#   MIGRATION_GROUP_ORDER (optional override)
# Outputs:
#   Space-separated group names to stdout
# Returns:
#   0 always
#######################################
_migrate_get_groups() {
  local -a groups=(proactive_config proactive-default sharedStorage customers)
  if [[ -n "${MIGRATION_GROUP_ORDER:-}" ]]; then
    local cleaned="${MIGRATION_GROUP_ORDER// /}"
    IFS=',' read -r -A groups <<< "${cleaned}"
  fi
  echo "${groups[@]}"
}

#######################################
# Execute artisan command in API container.
# Arguments:
#   1 - Container name
#   2+ - Artisan command and arguments
# Outputs:
#   Command output to stdout/stderr
# Returns:
#   Exit code from artisan command
#######################################
_migrate_exec() {
  local container="${1}"
  shift
  docker exec -it "${container}" php artisan "$@"
}

#######################################
# Run grouped migrations in default order.
# Arguments:
#   1 - Container name
# Outputs:
#   Migration status to stdout
# Returns:
#   Exit code from migrate-all command
#######################################
_migrate_all() {
  local container="${1}"
  local -a groups
  IFS=' ' read -r -A groups <<< "$(_migrate_get_groups)"
  echo "Running grouped migrations in order: ${groups[*]}"
  _migrate_exec "${container}" migrate-all --groups="$(
    IFS=,
    echo "${groups[*]}"
  )"
}

_migrate_debug() {
  local container="${1}"
  local -a groups
  IFS=' ' read -r -A groups <<< "$(_migrate_get_groups)"
  echo "Running each group separately (stops on first failure)"

  local group
  for group in "${groups[@]}"; do
    echo "=== Group: ${group} ==="
    _migrate_exec "${container}" migrate-all --groups="${group}" || {
      echo "Group '${group}' FAILED. Aborting debug run." >&2
      return 1
    }
  done
}

#######################################
# Run custom migration groups.
# Arguments:
#   1 - Container name
#   2 - Comma-separated group names
# Outputs:
#   Migration status to stdout
#   Error to stderr if groups empty
# Returns:
#   1 if groups empty, else artisan exit code
#######################################
_migrate_group() {
  local container="${1}" groups="${2}"
  [[ -z "${groups}" ]] && {
    echo "Usage: migrate group <g1,g2,...>" >&2
    return 1
  }
  echo "Running custom groups: ${groups}"
  _migrate_exec "${container}" migrate-all --groups="${groups}"
}

#######################################
# Run migrations for a specific path.
# Arguments:
#   1 - Container name
#   2 - Migration path (customers|config|sharedStorage)
# Outputs:
#   Migration status to stdout
# Returns:
#   Exit code from artisan migrate
#######################################
_migrate_path() {
  local container="${1}" path="${2}"
  _migrate_exec "${container}" migrate --path="database/migrations/${path}"
}

#######################################
# Rollback migrations for a specific path.
# Arguments:
#   1 - Container name
#   2 - Migration path (customers|config|sharedStorage)
# Outputs:
#   Rollback status to stdout
# Returns:
#   Exit code from artisan migrate:rollback
#######################################
_migrate_rollback_path() {
  local container="${1}" path="${2}"
  _migrate_exec "${container}" migrate:rollback --path="database/migrations/${path}"
}

#######################################
# Display migrate command usage.
# Outputs:
#   Help text to stdout
#######################################
_migrate_help() {
  cat << 'EOF'
Usage: migrate [all|debug|group <g1,g2,...>|customers|config|shared|rollback [target]|status|tinker]
  all        Run grouped migrate-all with default (or overridden) order
  debug      Run each group individually in sequence to isolate failures
  group      Run a custom comma-separated list of groups
  status     Show overall migration status
  tinker     Open artisan tinker within the API container (passes extra args)
  customers  Run only customers path migrations
  config     Run only config path migrations
  shared     Run only sharedStorage path migrations
  rollback   Roll back a specific path (customers|config|shared)

Environment:
  MIGRATION_GROUP_ORDER="proactive_config,proactive-default,sharedStorage,customers" (override order)

Tip: If you previously saw 'Call to a member function load() on null', ensure 'customers' runs last.
EOF
}

#######################################
# Manage SpendCloud database migrations.
# Arguments:
#   1 - Action: all|debug|group|status|tinker|customers|config|shared|rollback|help
#   2+ - Additional arguments depending on action
# Globals:
#   MIGRATION_GROUP_ORDER (optional override)
# Outputs:
#   Migration status and results to stdout
# Returns:
#   0 on success, 1 on failure or invalid option
#######################################
migrate() {
  local container
  container="$(_migrate_get_container)" || return 1

  case "${1:-all}" in
    all) _migrate_all "${container}" ;;
    debug | each) _migrate_debug "${container}" ;;
    group) _migrate_group "${container}" "${2}" ;;
    status) _migrate_exec "${container}" migrate:status ;;
    tinker) shift; _migrate_exec "${container}" tinker "$@" ;;
    customers) _migrate_path "${container}" "customers" ;;
    config) _migrate_path "${container}" "config" ;;
    shared | sharedstorage) _migrate_path "${container}" "sharedStorage" ;;
    rollback)
      case "${2:-customers}" in
        customers) _migrate_rollback_path "${container}" "customers" ;;
        config) _migrate_rollback_path "${container}" "config" ;;
        shared | sharedstorage) _migrate_rollback_path "${container}" "sharedStorage" ;;
        *)
          echo "Invalid rollback target: ${2}" >&2
          return 1
          ;;
      esac
      ;;
    help | -h | --help) _migrate_help ;;
    *)
      echo "Invalid migrate option: ${1}" >&2
      echo "Run: migrate help" >&2
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# NUKE COMMAND (Dangerous client cleanup tool)
# ═══════════════════════════════════════════════════════════════════════════════

#######################################
# Print nuke error message to stderr.
# Arguments:
#   * - Error message text
# Outputs:
#   Writes to stderr
#######################################
_nuke_err() { printf 'ERROR: %s\n' "$*" >&2; }

#######################################
# Print nuke warning message to stderr.
# Arguments:
#   * - Warning message text
# Outputs:
#   Writes to stderr
#######################################
_nuke_warn() { printf 'WARN: %s\n' "$*" >&2; }

#######################################
# Print nuke info message to stdout.
# Arguments:
#   * - Info message text
# Outputs:
#   Writes to stdout
#######################################
_nuke_info() { printf '%s\n' "$*"; }

#######################################
# Prompt user for confirmation.
# Arguments:
#   1 - Prompt text
#   2 - Expected exact response
# Outputs:
#   Prompt to stderr
# Returns:
#   0 if response matches expected, 1 otherwise
#######################################
_nuke_confirm() {
  local prompt="${1}" expected="${2}" reply
  printf '%s' "${prompt}" >&2
  read -r reply || return 1
  [[ "${reply}" == "${expected}" ]]
}

#######################################
# Get the spend-cloud-api container name.
# Outputs:
#   Container name to stdout if found
# Returns:
#   0 always (empty if not found)
#######################################
_nuke_get_container() {
  docker ps --format '{{.Names}}' | grep -E '^spend-cloud-api$' | head -1
}

#######################################
# Execute SQL query in API container.
# Arguments:
#   1 - Container name
#   2+ - SQL query
# Globals:
#   DB_USERNAME
#   DB_PASSWORD
#   DB_SERVICES_HOST
#   NUKE_CONFIG_DB
# Outputs:
#   Query results to stdout
# Returns:
#   Exit code from mysql command
#######################################
_nuke_sql() {
  local container="${1}"
  shift
  local -a cmd=(docker exec -i "${container}" mysql -u"${DB_USERNAME}" -h "${DB_SERVICES_HOST}" "${NUKE_CONFIG_DB}")
  [[ -n "${DB_PASSWORD}" ]] && cmd+=(-p"${DB_PASSWORD}")
  "${cmd[@]}" -N -e "$*" 2> /dev/null
}

#######################################
# Get list of eligible client names from multiple sources.
# Arguments:
#   1 - Container name
#   2 - Settings table name
# Outputs:
#   Client names (one per line) to stdout
# Returns:
#   0 always (empty if no clients)
#######################################
_nuke_get_clients() {
  local container="${1}" settings_table="${2}"
  local folder_clients settings_clients table_clients

  folder_clients="$(docker exec "${container}" bash -lc \
    'ls -1 /data 2>/dev/null | grep -Ev "^(test|lost\+found)$"' || true)"

  settings_clients="$(_nuke_sql "${container}" \
    "SELECT DISTINCT \`043\` FROM ${settings_table} WHERE \`043\` IS NOT NULL AND \`043\` != ''" |
    tr '[:upper:]' '[:lower:]' || true)"

  printf '%s\n%s\n%s\n' "${folder_clients}" "${settings_clients}" "${table_clients}" |
    awk 'NF' | sort -u |
    grep -Ev '^(proactive_accounts\.ini|spend-cloud|oci)$' || true
}

#######################################
# Interactively select client from list.
# Arguments:
#   1 - Newline-separated client list
# Globals:
#   C_CYAN, C_RESET (for non-fzf mode)
# Outputs:
#   Selected client name to stdout
#   Selection prompt to stderr (if not using fzf)
# Returns:
#   0 always (empty if no selection)
#######################################
_nuke_select_client() {
  local filtered="${1}"
  local target

  if command -v fzf > /dev/null 2>&1; then
    target="$(echo "${filtered}" | fzf --prompt="Select client > ")"
  else
    _nuke_info "${C_CYAN}Select client:${C_RESET}" >&2
    local -a selection
    local i=1 choice
    readarray -t selection <<< "${filtered}"
    for choice in "${selection[@]}"; do
      printf '%2d) %s\n' "${i}" "${choice}" >&2
      ((i++))
    done
    printf 'Enter number: ' >&2
    local num
    read -r num
    if [[ "${num}" =~ ^[0-9]+$ ]] && ((num >= 1 && num < i)); then
      target="${selection[num - 1]}"
    fi
  fi

  echo "${target}"
}

#######################################
# Analyze client data across all sources.
# Arguments:
#   1 - Container name
#   2 - Client name
#   3 - Settings table name
# Globals:
#   C_CYAN, C_RESET
# Outputs:
#   Analysis report to stdout
#   Encoded analysis string (last line) for parsing
# Returns:
#   0 always
#######################################
_nuke_analyze() {
  local container="${1}" target="${2}" settings_table="${3}"
  local client_id has_folder=0 has_settings=0 has_client_row=0 dbs

  dbs="$(_nuke_sql "${container}" "SHOW DATABASES" |
    grep -i "${target}" |
    grep -Ev '^(information_schema|mysql|performance_schema|sys)$' || true)"

  local folder_clients settings_clients
  folder_clients="$(docker exec "${container}" bash -lc 'ls -1 /data 2>/dev/null' || true)"
  settings_clients="$(_nuke_sql "${container}" \
    "SELECT DISTINCT \`043\` FROM ${settings_table} WHERE \`043\` IS NOT NULL AND \`043\` != ''" || true)"

  echo "${folder_clients}" | grep -Fx "${target}" > /dev/null && has_folder=1
  echo "${settings_clients}" | grep -Fx "${target}" > /dev/null && has_settings=1

  _nuke_info "${C_CYAN}Analysis for '${target}':${C_RESET}"
  printf '  - /data folder: %s\n' "$([[ ${has_folder} -eq 1 ]] && echo present || echo absent)"
  printf '  - %s entry: %s\n' "${settings_table}" "$([[ ${has_settings} -eq 1 ]] && echo present || echo absent)"
  printf '  - 00_client row: %s\n' "$([[ ${has_client_row} -eq 1 ]] && echo present || echo absent)"

  if [[ -n "${dbs}" ]]; then
    _nuke_info '  - databases:'
    while IFS= read -r _db; do
      printf '      * %s\n' "${_db}"
    done <<< "${dbs}"
  else
    _nuke_info '  - databases: none'
  fi

  echo "${has_folder}:${has_settings}:${has_client_row}:${dbs}:${client_id}"
}

#######################################
# Execute destructive client cleanup.
# Arguments:
#   1 - Container name
#   2 - Client name
#   3 - Settings table name
#   4 - Analysis string from _nuke_analyze
# Globals:
#   C_RED, C_GREEN, C_RESET
# Outputs:
#   Execution status messages to stdout
# Returns:
#   0 always
#######################################
_nuke_execute() {
  local container="${1}" target="${2}" settings_table="${3}" analysis="${4}"
  local has_folder has_settings has_client_row dbs client_id
  IFS=':' read -r has_folder has_settings has_client_row dbs client_id <<< "${analysis}"

  _nuke_info "${C_RED}Executing NUKE...${C_RESET}"

  # Drop databases
  if [[ -n "${dbs}" ]]; then
    while IFS= read -r db; do
      [[ -z "${db}" ]] && continue
      _nuke_info "  - drop db ${db}"
      _nuke_sql "${container}" "DROP DATABASE IF EXISTS \`${db}\`;" > /dev/null ||
        _nuke_warn "    (warn) drop failed ${db}"
    done <<< "${dbs}"
  fi

  # Purge settings
  ((has_settings == 1)) && {
    _nuke_info "  - purge ${settings_table}"
    _nuke_sql "${container}" \
      "DELETE FROM ${settings_table} WHERE LOWER(\`043\`)=LOWER('${target}')" > /dev/null ||
      _nuke_warn "    (warn) purge failed"
  }

  # Remove data folder
  docker exec "${container}" test -d "/data/${target}" && {
    docker exec "${container}" rm -rf "/data/${target}" &&
      _nuke_info "  - removed /data/${target}" ||
      _nuke_warn "  - (warn) folder removal failed"
  }

  _nuke_info "${C_GREEN}Done. Run: nuke --verify ${target}${C_RESET}"
}

#######################################
# Display nuke command usage.
# Outputs:
#   Help text to stdout
#######################################
_nuke_help() {
  cat << 'EOF'
Usage: nuke [--verify] [clientName]
  --verify | -v   Analyze only; no destructive actions
  --help   | -h   Show this help
  clientName      Target client (if omitted, interactive selection)
Environment vars:
  DB_USERNAME (default: root)
  DB_PASSWORD (default: <empty>)
  DB_SERVICES_HOST (default: mysql-service)
  NUKE_CONFIG_DB (default: spend-cloud-config)
Description:
  Performs a destructive cleanup for a client across:
    - config DB row(s) in settings tables
    - 00_client row & related tables
    - per-client databases
    - /data/<client> folder
Safety:
  Dual confirmation; blacklist of protected names; verify mode.
EOF
}

#######################################
# DANGEROUS multi-tenant client cleanup tool.
# Performs destructive cleanup across databases, settings, and filesystem.
# Arguments:
#   [--verify|-v] - Analyze only, no destructive actions
#   [--help|-h]   - Show usage
#   [clientName]  - Target client (interactive if omitted)
# Globals:
#   ENABLE_NUKE (required to be set for execution)
#   DB_USERNAME, DB_PASSWORD, DB_SERVICES_HOST, NUKE_CONFIG_DB
# Outputs:
#   Analysis and execution status to stdout
#   Errors to stderr
# Returns:
#   0 on success/safe abort, 1-5 on errors, 99 if ENABLE_NUKE not set
#######################################
nuke() {
  [[ -z "${ENABLE_NUKE:-}" ]] && {
    echo "Refusing to run: set ENABLE_NUKE=1 to allow nuke (export ENABLE_NUKE=1)" >&2
    return 99
  }

  # Set defaults
  : "${DB_USERNAME:=root}" "${DB_PASSWORD:=}" "${DB_SERVICES_HOST:=mysql-service}" "${NUKE_CONFIG_DB:=spend-cloud-config}"

  local mode="normal" target="" container settings_table="00_settings"
  local -r blacklist_regex='^(prod|production|shared|sharedstorage|system|default|oci)$'

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --verify | -v) mode="verify"; shift ;;
      --help | -h) _nuke_help; return 0 ;;
      --) shift; break ;;
      -*)
        _nuke_err "Unknown flag: ${1}"
        _nuke_help
        return 2
        ;;
      *)
        [[ -z "${target}" ]] && target="${1}" || {
          _nuke_err "Unexpected extra arg: ${1}"
          return 2
        }
        shift
        ;;
    esac
  done

  # Get container
  container="$(_nuke_get_container)" || {
    _nuke_err "API container not running"
    return 3
  }

  # Detect settings table
  _nuke_sql "${container}" "SHOW TABLES LIKE 'client_settings'" | grep -q '^client_settings$' &&
    settings_table='client_settings'

  # Get eligible clients
  local filtered
  filtered="$(_nuke_get_clients "${container}" "${settings_table}")"
  [[ -z "${filtered}" ]] && {
    _nuke_warn "No eligible clients to operate on."
    return 0
  }

  # Select target if not provided
  [[ -z "${target}" ]] && {
    target="$(_nuke_select_client "${filtered}")"
    [[ -z "${target}" ]] && {
      _nuke_warn "No client selected"
      return 0
    }
  }

  # Validate target
  [[ "${target}" =~ ${blacklist_regex} ]] && {
    _nuke_err "Target '${target}' is protected"
    return 4
  }
  echo "${filtered}" | grep -Fx "${target}" > /dev/null || {
    _nuke_err "Target '${target}' not in candidate list"
    return 5
  }

  # Analyze
  local analysis
  analysis="$(_nuke_analyze "${container}" "${target}" "${settings_table}")"

  # Verify mode: exit after analysis
  [[ "${mode}" == "verify" ]] && {
    _nuke_info "${C_GREEN}Verify mode: no changes made.${C_RESET}"
    return 0
  }

  # Confirm destruction
  _nuke_confirm "${C_YELLOW}Proceed to NUKE '${target}'? (yes/no) ${C_RESET}" 'yes' || {
    _nuke_info "${C_GREEN}Aborted.${C_RESET}"
    return 0
  }
  _nuke_confirm "${C_RED}Type the client name to confirm: ${C_RESET}" "${target}" || {
    _nuke_info "${C_GREEN}Mismatch. Aborted.${C_RESET}"
    return 1
  }

  # Execute destruction
  _nuke_execute "${container}" "${target}" "${settings_table}" "${analysis}"
}
