#!/usr/bin/env zsh
#
# Optional SpendCloud / Proactive Frame / Cluster tooling module.
# Loaded only when ENABLE_SPEND_CLOUD=1 or via enable-spendcloud command.
# Keeps main ~/.zshrc lean for general environments.
#
# This module provides:
# - Project navigation aliases and functions
# - Cluster management (start/stop/logs)
# - Database migration helpers
# - Client cleanup utilities (nuke)
# - Development environment PATH extensions

# Guard against duplicate loading
if [[ -n "${_SPEND_CLOUD_MODULE_LOADED:-}" ]]; then
  return 0
fi
readonly _SPEND_CLOUD_MODULE_LOADED=1

# ────────────────────────────────────────────────────────────────────────────────
# Project Navigation Aliases
# ────────────────────────────────────────────────────────────────────────────────
alias sc='cd ~/development/spend-cloud'
alias scapi='sc && cd api'
alias scui='sc && cd ui'
alias cui='code ~/development/spend-cloud/ui'
alias capi='code ~/development/spend-cloud/api'
alias devapi='scapi && sct dev'

alias pf='cd ~/development/proactive-frame'
alias cpf='code ~/development/proactive-frame'

# ────────────────────────────────────────────────────────────────────────────────
# Cluster Management Functions
# ────────────────────────────────────────────────────────────────────────────────

#######################################
# Manages SpendCloud cluster lifecycle and development services.
# Provides start/stop/rebuild/logs functionality for cluster and dev containers.
# Arguments:
#   $1 - Command: stop|logs|help|--rebuild or empty for start
#   $2 - Service name (for logs command only)
# Outputs:
#   Status messages to STDOUT with color formatting
# Returns:
#   0 on success, 1 on cluster start failure
#######################################
cluster() {
  local red='\033[0;31m'
  local green='\033[0;32m'
  local yellow='\033[1;33m'
  local blue='\033[0;34m'
  local purple='\033[0;35m'
  local cyan='\033[0;36m'
  local white='\033[1;37m'
  local nc='\033[0m'
  local original_dir
  original_dir="$(pwd)"
  if [[ "${1}" == "stop" ]]; then
    echo -e "${yellow}🛑 Stopping all cluster services...${nc}"
    echo -e "${cyan}🔍 Stopping and removing all containers...${nc}"
    local dev_containers
    dev_containers="$(docker ps -a --format "{{.Names}}" |
      grep -E '(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)')"
    if [[ -n "${dev_containers}" ]]; then
      echo "${dev_containers}" | xargs -r docker stop 2> /dev/null || true
      echo "${dev_containers}" | xargs -r docker rm 2> /dev/null || true
      echo -e "${green}✅ Containers stopped and removed${nc}"
    fi
    echo -e "${blue}🛑 Stopping SCT cluster...${nc}"
    sct cluster stop
    echo -e "${green}✅ Cluster stopped successfully${nc}"
    return 0
  fi
  if [[ "${1}" == "logs" ]]; then
    if [[ -n "${2}" ]]; then
      echo -e "${cyan}📋 Showing logs for service: ${2}${nc}"
      sct cluster logs "${2}"
    else
      echo -e "${cyan}📋 Showing logs for all cluster services...${nc}"
      sct cluster logs
    fi
    return 0
  fi
  if [[ "${1}" == "help" || "${1}" == "-h" || "${1}" == "--help" ]]; then
    cat << 'EOF'
SpendCloud Cluster Management
Usage: cluster [--rebuild|stop|logs [service]|help]
  (no args)       Start cluster and dev services (api + proactive frame)
  --rebuild       Rebuild and start cluster with fresh images
  stop            Stop all cluster and dev services
  logs [service]  Show logs (all or specific)
  help            Show this message
EOF
    return 0
  fi
  echo -e "${cyan}🔍 Checking for existing containers...${nc}"
  local dev_containers
  dev_containers="$(docker ps -a --format "{{.Names}}" |
    grep -E '(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)' |
    head -15)"
  if [[ -n "${dev_containers}" ]]; then
    echo -e "${yellow}⚠️  Found existing containers that may conflict:${nc}"
    while IFS= read -r container; do
      echo -e "  • ${container}"
    done <<< "${dev_containers}"
    echo -e "${yellow}🛑 Stopping and removing containers before cluster operation...${nc}"
    echo "${dev_containers}" | xargs -r docker stop 2> /dev/null || true
    echo "${dev_containers}" | xargs -r docker rm 2> /dev/null || true
    echo -e "${green}✅ Containers stopped and removed${nc}"
  else
    echo -e "${green}✅ No conflicting containers found${nc}"
  fi
  if [[ "${1}" == "--rebuild" ]]; then
    echo -e "${yellow}🔄 Rebuilding cluster with fresh images...${nc}"
    echo -e "${blue}🚀 Starting SCT cluster...${nc}"
    if ! sct cluster start --build --pull; then
      echo -e "${red}❌ Failed to start SCT cluster. Aborting...${nc}"
      return 1
    fi
  else
    echo -e "${blue}🚀 Starting SCT cluster...${nc}"
    if ! sct cluster start; then
      echo -e "${red}❌ Failed to start SCT cluster. Aborting...${nc}"
      return 1
    fi
  fi
  sleep 2
  echo -e "${purple}⚡ Starting dev for spend-cloud/api...${nc}"
  cd "${HOME}/development/spend-cloud/api" || return 1
  sct dev > /dev/null 2>&1 &
  echo -e "${cyan}⚡ Starting dev for spend-cloud/proactive-frame...${nc}"
  cd "${HOME}/development/proactive-frame" || return 1
  sct dev > /dev/null 2>&1 &
  cd "${original_dir}" || return 1
  echo -e "${green}✅ All services started!${nc}"
  echo -e "${white}🌟 SCT cluster + dev services running in background.${nc}"
}

#######################################
# Manages SpendCloud database migrations across multiple groups.
# Provides grouped migration execution, debugging, and rollback functionality.
# Arguments:
#   $1 - Action: all|debug|group|status|tinker|customers|config|shared|rollback|help
#   $2+ - Additional arguments (group names, rollback target, tinker commands)
# Globals:
#   MIGRATION_GROUP_ORDER - Optional CSV override for default group order
# Outputs:
#   Migration status and results to STDOUT
# Returns:
#   0 on success, 1 on failure or missing container
#######################################
migrate() {
  local container
  container="$(docker ps --format '{{.Names}}' |
    grep -E 'spend.*cloud.*api|api.*spend.*cloud' |
    head -1)"
  if [[ -z "${container}" ]]; then
    echo "API container not found. Start with 'cluster'." >&2
    return 1
  fi
  # Allow override of default group order via env var MIGRATION_GROUP_ORDER
  # New default order moves 'customers' LAST to ensure config/settings tables exist first
  local -a default_groups=(proactive_config proactive-default sharedStorage customers)
  if [[ -n "${MIGRATION_GROUP_ORDER:-}" ]]; then
    # Split CSV into array (strip spaces)
    local cleaned
    cleaned="${MIGRATION_GROUP_ORDER// /}"
    IFS=',' read -r -A default_groups <<< "${cleaned}"
  fi

  local action="${1:-all}"
  case "${action}" in
    all)
      echo "Running grouped migrations in order: ${default_groups[*]}"
      docker exec -it "${container}" php artisan migrate-all \
        --groups="$(
          IFS=,
          echo "${default_groups[*]}"
        )" || return 1
      ;;
    debug | each)
      echo "Running each group separately (stops on first failure)"
      local group
      for group in "${default_groups[@]}"; do
        echo "=== Group: ${group} ==="
        if ! docker exec -it "${container}" php artisan migrate-all \
          --groups="${group}"; then
          echo "Group '${group}' FAILED. Aborting debug run." >&2
          return 1
        fi
      done
      ;;
    group)
      shift
      if [[ -z "${1:-}" ]]; then
        echo "Usage: migrate group <g1,g2,...>" >&2
        return 1
      fi
      echo "Running custom groups: ${1}"
      docker exec -it "${container}" php artisan migrate-all --groups="${1}"
      ;;
    status)
      docker exec -it "${container}" php artisan migrate:status
      ;;
    tinker)
      shift
      docker exec -it "${container}" php artisan tinker "$@"
      ;;
    customers)
      docker exec -it "${container}" php artisan migrate \
        --path=database/migrations/customers
      ;;
    config)
      docker exec -it "${container}" php artisan migrate \
        --path=database/migrations/config
      ;;
    shared | sharedstorage)
      docker exec -it "${container}" php artisan migrate \
        --path=database/migrations/sharedStorage
      ;;
    rollback)
      local target="${2:-customers}"
      case "${target}" in
        customers)
          docker exec -it "${container}" php artisan migrate:rollback \
            --path=database/migrations/customers
          ;;
        config)
          docker exec -it "${container}" php artisan migrate:rollback \
            --path=database/migrations/config
          ;;
        shared | sharedstorage)
          docker exec -it "${container}" php artisan migrate:rollback \
            --path=database/migrations/sharedStorage
          ;;
        *)
          echo "Invalid rollback target: ${target}" >&2
          return 1
          ;;
      esac
      ;;
    help | -h | --help)
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
      return 0
      ;;
    *)
      echo "Invalid migrate option: ${action}" >&2
      echo "Run: migrate help" >&2
      return 1
      ;;
  esac
}

# ────────────────────────────────────────────────────────────────────────────────
# Client Management Functions
# ────────────────────────────────────────────────────────────────────────────────

#######################################
# DANGEROUS multi-tenant cleanup tool; drops databases & rows.
# Performs destructive cleanup for a client across multiple data stores.
# Arguments:
#   [--verify|-v] (optional) perform analysis only
#   [--help|-h]   show usage
#   [clientName]  target client (otherwise interactive picker)
# Globals:
#   DB_USERNAME, DB_PASSWORD, DB_SERVICES_HOST, NUKE_CONFIG_DB (optional overrides)
#   ENABLE_NUKE (required to be set for execution)
# Outputs:
#   Human-readable analysis to STDOUT; warnings/errors to STDERR
# Returns:
#   0 on success / safe aborts; >0 on errors; 99 if ENABLE_NUKE not set
#######################################
nuke() {
  # Optional additional guard: require ENABLE_NUKE env var; comment out to disable
  if [[ -z "${ENABLE_NUKE:-}" ]]; then
    echo "Refusing to run: set ENABLE_NUKE=1 to allow nuke (export ENABLE_NUKE=1)" >&2
    return 99
  fi

  # Helper functions for consistent output formatting
  err() { printf 'ERROR: %s\n' "$*" >&2; }
  warn() { printf 'WARN: %s\n' "$*" >&2; }
  info() { printf '%s\n' "$*"; }

  usage() {
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
    - config DB row(s) in 00_settings or client_settings
    - 00_client row & related * tables referencing client_id
    - potential per-client databases (matching client pattern)
    - /data/<client> folder (in container)
Safety:
  Dual confirmation; blacklist of protected names; verify mode.
EOF
  }

  confirm() {
    local prompt="${1}"
    local expected="${2}"
    local reply
    printf '%s' "${prompt}" >&2
    read -r reply || return 1
    [[ "${reply}" == "${expected}" ]]
  }

  local mode="normal"
  local target=""
  local container
  local settings_table="00_settings"
  local -r blacklist_regex='^(prod|production|shared|sharedstorage|system|default|oci)$'
  local -r master_blacklist_pattern='^(proactive_accounts\.ini|spend-cloud|oci)$'

  # Colors (disable if NO_COLOR or not a TTY)
  local color_red color_green color_yellow color_cyan color_none
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    color_red=$'\e[0;31m'
    color_green=$'\e[0;32m'
    color_yellow=$'\e[1;33m'
    color_cyan=$'\e[0;36m'
    color_none=$'\e[0m'
  else
    color_red=""
    color_green=""
    color_yellow=""
    color_cyan=""
    color_none=""
  fi

  # Set default values for database connection
  : "${DB_USERNAME:=root}"
  : "${DB_PASSWORD:=}"
  : "${DB_SERVICES_HOST:=mysql-service}"
  : "${NUKE_CONFIG_DB:=spend-cloud-config}"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --verify | -v)
        mode="verify"
        shift
        ;;
      --help | -h)
        usage
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        err "Unknown flag: ${1}"
        usage
        return 2
        ;;
      *)
        if [[ -z "${target}" ]]; then
          target="${1}"
        else
          err "Unexpected extra arg: ${1}"
          return 2
        fi
        shift
        ;;
    esac
  done

  container="$(docker ps --format '{{.Names}}' |
    grep -E '^spend-cloud-api$' |
    head -1)"
  if [[ -z "${container}" ]]; then
    err "API container not running"
    return 3
  fi

  local -a mysql_base=(docker exec -i "${container}" mysql
    -u"${DB_USERNAME}" -h "${DB_SERVICES_HOST}" "${NUKE_CONFIG_DB}")
  if [[ -n "${DB_PASSWORD}" ]]; then
    mysql_base=(docker exec -i "${container}" mysql
      -u"${DB_USERNAME}" -p"${DB_PASSWORD}"
      -h "${DB_SERVICES_HOST}" "${NUKE_CONFIG_DB}")
  fi

  _sql() { "${mysql_base[@]}" -N -e "${1}" 2> /dev/null; }

  if _sql "SHOW TABLES LIKE 'client_settings'" | grep -q '^client_settings$'; then
    settings_table='client_settings'
  fi

  if ! _sql "SHOW COLUMNS FROM ${settings_table} LIKE '043'" > /dev/null; then
    warn "Column '043' not found in ${settings_table}. Cannot map client names reliably."
    warn "Falling back to folder and 00_client derived names only."
  fi

  local folder_clients settings_clients table_clients all_candidates filtered client_table_col
  folder_clients="$(docker exec "${container}" bash -lc \
    'ls -1 /data 2>/dev/null | grep -Ev "^(test|lost\+found)$"' || true)"
  settings_clients="$(_sql "SELECT DISTINCT \`043\` FROM ${settings_table} WHERE \`043\` IS NOT NULL AND \`043\` != ''" |
    tr '[:upper:]' '[:lower:]' || true)"
  if [[ -n "${client_table_col:-}" ]]; then
    table_clients="$(_sql "SELECT DISTINCT ${client_table_col} FROM 00_client WHERE ${client_table_col} IS NOT NULL AND ${client_table_col} != ''" |
      tr '[:upper:]' '[:lower:]')"
  fi
  all_candidates="$(printf '%s\n%s\n%s\n' "${folder_clients}" "${settings_clients}" "${table_clients}" |
    awk 'NF' | sort -u)"
  filtered="$(echo "${all_candidates}" | grep -Ev "${master_blacklist_pattern}" || true)"
  if [[ -z "${filtered}" ]]; then
    warn "No eligible clients to operate on (after blacklist & data sources)."
    return 0
  fi

  if [[ -z "${target}" ]]; then
    if command -v fzf > /dev/null 2>&1; then
      target="$(echo "${filtered}" | fzf --prompt="Select client > ")"
    else
      info "${color_cyan}Select client:${color_none}" >&2
      local -a selection
      local i=1
      local choice
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
    if [[ -z "${target}" ]]; then
      warn "No client selected"
      return 0
    fi
  fi

  if [[ "${target}" =~ ${blacklist_regex} ]]; then
    err "Target '${target}' is protected"
    return 4
  fi
  if ! echo "${filtered}" | grep -Fx "${target}" > /dev/null; then
    err "Target '${target}' not in candidate list"
    return 5
  fi

  local client_id
  local has_folder=0
  local has_settings=0
  local has_client_row=0
  local dbs
  dbs="$(_sql "SHOW DATABASES" |
    grep -i "${target}" |
    grep -Ev '^(information_schema|mysql|performance_schema|sys)$' || true)"
  if [[ -n "${client_table_col:-}" ]]; then
    client_id="$(_sql "SELECT id FROM 00_client WHERE LOWER(${client_table_col})=LOWER('${target}') LIMIT 1")"
  fi
  if echo "${folder_clients}" | grep -Fx "${target}" > /dev/null; then
    has_folder=1
  fi
  if echo "${settings_clients}" | grep -Fx "${target}" > /dev/null; then
    has_settings=1
  fi
  if [[ -n "${client_id:-}" ]]; then
    has_client_row=1
  fi

  info "${color_cyan}Analysis for '${target}':${color_none}"
  printf '  - /data folder: %s\n' "$(if [[ ${has_folder} -eq 1 ]]; then echo present; else echo absent; fi)"
  printf '  - %s entry (col 043): %s\n' "${settings_table}" "$(if [[ ${has_settings} -eq 1 ]]; then echo present; else echo absent; fi)"
  printf '  - 00_client row: %s\n' "$(if [[ ${has_client_row} -eq 1 ]]; then echo present; else echo absent; fi)"
  if [[ -n "${dbs}" ]]; then
    info '  - databases:'
    while IFS= read -r _db; do
      printf '      * %s\n' "${_db}"
    done <<< "${dbs}"
  else
    info '  - databases: none'
  fi

  if [[ "${mode}" == 'verify' ]]; then
    info "${color_green}Verify mode: no changes made.${color_none}"
    return 0
  fi

  if ! confirm "${color_yellow}Proceed to NUKE '${target}'? (yes/no) ${color_none}" 'yes'; then
    info "${color_green}Aborted.${color_none}"
    return 0
  fi
  if ! confirm "${color_red}Type the client name to confirm: ${color_none}" "${target}"; then
    info "${color_green}Mismatch. Aborted.${color_none}"
    return 1
  fi
  info "${color_red}Executing NUKE...${color_none}"

  if [[ -n "${dbs}" ]]; then
    while IFS= read -r db; do
      [[ -z "${db}" ]] && continue
      info "  - drop db ${db}"
      _sql "DROP DATABASE IF EXISTS \`${db}\`;" > /dev/null ||
        warn "    (warn) drop failed ${db}"
    done <<< "${dbs}"
  fi

  if ((has_settings == 1)); then
    info "  - purge ${settings_table}"
    _sql "DELETE FROM ${settings_table} WHERE LOWER(\`043\`)=LOWER('${target}')" > /dev/null ||
      warn "    (warn) purge failed"
  fi

  if [[ -n "${client_id:-}" ]]; then
    local related
    related="$(_sql "SELECT table_name FROM information_schema.columns WHERE table_schema=DATABASE() AND column_name='client_id'")"
    if [[ -n "${related}" ]]; then
      while IFS= read -r table; do
        [[ -z "${table}" ]] && continue
        info "    * purge ${table}"
        _sql "DELETE FROM \`${table}\` WHERE client_id=${client_id}" > /dev/null ||
          warn "      (warn) rel purge failed ${table}"
      done <<< "${related}"
    fi
    info "  - delete 00_client row"
    _sql "DELETE FROM 00_client WHERE id=${client_id}" > /dev/null ||
      warn "    (warn) client row delete failed"
  fi

  if docker exec "${container}" test -d "/data/${target}"; then
    if docker exec "${container}" rm -rf "/data/${target}"; then
      info "  - removed /data/${target}"
    else
      warn "  - (warn) folder removal failed"
    fi
  fi

  info "${color_green}Done. Run: nuke --verify ${target}${color_none}"
  return 0
}

# ────────────────────────────────────────────────────────────────────────────────
# Environment PATH Extensions
# ────────────────────────────────────────────────────────────────────────────────

# Google Cloud SDK integration
if [[ -f '/home/tom/google-cloud-sdk/path.zsh.inc' ]]; then
  # shellcheck disable=SC1091
  . '/home/tom/google-cloud-sdk/path.zsh.inc'
fi
if [[ -f '/home/tom/google-cloud-sdk/completion.zsh.inc' ]]; then
  # shellcheck disable=SC1091
  . '/home/tom/google-cloud-sdk/completion.zsh.inc'
fi
export PATH="${PATH}:/home/tom/google-cloud-sdk/bin"

# Development tools PATH extensions
export PATH="${PATH}:${HOME}/.composer/vendor/bin"
if command -v yarn > /dev/null 2>&1; then
  export PATH="${PATH}:$(yarn global bin)"
fi
export PATH="${PATH}:${HOME}/.local/bin"

# ASDF version manager (optional)
if [[ -f "${HOME}/.asdf/asdf.sh" ]]; then
  # shellcheck disable=SC1091 # optional ASDF environment script (dynamic, may not exist)
  . "${HOME}/.asdf/asdf.sh"
fi

# End optional module
