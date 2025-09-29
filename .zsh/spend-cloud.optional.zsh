# Optional SpendCloud / Proactive Frame / Cluster tooling
# Loaded only when ENABLE_SPEND_CLOUD=1 or via enable-spendcloud command.
# Keeps main ~/.zshrc lean for general environments.

# Guard against duplicate loading
if [[ -n "${_SPEND_CLOUD_MODULE_LOADED:-}" ]]; then
  return 0
fi
_SPEND_CLOUD_MODULE_LOADED=1

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
# Cluster Management (cluster)
# ────────────────────────────────────────────────────────────────────────────────
cluster() {
  local RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' WHITE='\033[1;37m' NC='\033[0m'
  local original_dir=$(pwd)
  if [[ "$1" == stop ]]; then
    echo -e "${YELLOW}🛑 Stopping all cluster services...${NC}"
    echo -e "${CYAN}🔍 Stopping and removing all containers...${NC}"
    local dev_containers=$(docker ps -a --format "{{.Names}}" | grep -E '(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)')
    if [[ -n "$dev_containers" ]]; then
      echo "$dev_containers" | xargs -r docker stop 2>/dev/null || true
      echo "$dev_containers" | xargs -r docker rm 2>/dev/null || true
      echo -e "${GREEN}✅ Containers stopped and removed${NC}"
    fi
    echo -e "${BLUE}🛑 Stopping SCT cluster...${NC}"
    sct cluster stop
    echo -e "${GREEN}✅ Cluster stopped successfully${NC}"
    return 0
  fi
  if [[ "$1" == logs ]]; then
    if [[ -n "$2" ]]; then
      echo -e "${CYAN}📋 Showing logs for service: $2${NC}"
      sct cluster logs "$2"
    else
      echo -e "${CYAN}📋 Showing logs for all cluster services...${NC}"
      sct cluster logs
    fi
    return 0
  fi
  if [[ "$1" == help || "$1" == -h || "$1" == --help ]]; then
    cat <<'EOF'
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
  echo -e "${CYAN}🔍 Checking for existing containers...${NC}"
  local dev_containers=$(docker ps -a --format "{{.Names}}" | grep -E '(spend-cloud.*dev|proactive-frame.*dev|api.*dev|ui.*dev|proactive-frame|spend-cloud-api|spend-cloud-ui)' | head -15)
  if [[ -n "$dev_containers" ]]; then
    echo -e "${YELLOW}⚠️  Found existing containers that may conflict:${NC}"
    while IFS= read -r container; do echo -e "  • $container"; done <<< "$dev_containers"
    echo -e "${YELLOW}🛑 Stopping and removing containers before cluster operation...${NC}"
    echo "$dev_containers" | xargs -r docker stop 2>/dev/null || true
    echo "$dev_containers" | xargs -r docker rm 2>/dev/null || true
    echo -e "${GREEN}✅ Containers stopped and removed${NC}"
  else
    echo -e "${GREEN}✅ No conflicting containers found${NC}"
  fi
  if [[ "$1" == --rebuild ]]; then
    echo -e "${YELLOW}🔄 Rebuilding cluster with fresh images...${NC}"
    echo -e "${BLUE}🚀 Starting SCT cluster...${NC}"
    if ! sct cluster start --build --pull; then
      echo -e "${RED}❌ Failed to start SCT cluster. Aborting...${NC}"; return 1
    fi
  else
    echo -e "${BLUE}🚀 Starting SCT cluster...${NC}"
    if ! sct cluster start; then
      echo -e "${RED}❌ Failed to start SCT cluster. Aborting...${NC}"; return 1
    fi
  fi
  sleep 2
  echo -e "${PURPLE}⚡ Starting dev for spend-cloud/api...${NC}"; cd ~/development/spend-cloud/api; sct dev > /dev/null 2>&1 &
  echo -e "${CYAN}⚡ Starting dev for spend-cloud/proactive-frame...${NC}"; cd ~/development/proactive-frame; sct dev > /dev/null 2>&1 &
  cd "$original_dir"
  echo -e "${GREEN}✅ All services started!${NC}"
  echo -e "${WHITE}🌟 SCT cluster + dev services running in background.${NC}"
}

# Full migrate function (SpendCloud database migration management)
migrate() {
  local container
  container=$(docker ps --format '{{.Names}}' | grep -E 'spend.*cloud.*api|api.*spend.*cloud' | head -1)
  if [[ -z "$container" ]]; then
    echo "API container not found. Start with 'cluster'."
    return 1
  fi
  # Allow override of default group order via env var MIGRATION_GROUP_ORDER
  # New default order moves 'customers' LAST to ensure config/settings tables exist first
  local DEFAULT_GROUPS=(proactive_config proactive-default sharedStorage customers)
  if [[ -n "${MIGRATION_GROUP_ORDER}" ]]; then
    # Split CSV into array (strip spaces)
    local cleaned=${MIGRATION_GROUP_ORDER// /}
    IFS=',' read -r -A DEFAULT_GROUPS <<< "$cleaned"
  fi

  local action="${1:-all}"
  case "$action" in
    all)
      echo "Running grouped migrations in order: ${DEFAULT_GROUPS[*]}"
      docker exec -it "$container" php artisan migrate-all --groups="$(IFS=,; echo "${DEFAULT_GROUPS[*]}")" || return 1
      ;;
    debug|each)
      echo "Running each group separately (stops on first failure)"
      local g
      for g in "${DEFAULT_GROUPS[@]}"; do
        echo "=== Group: $g ==="
        if ! docker exec -it "$container" php artisan migrate-all --groups="$g"; then
          echo "Group '$g' FAILED. Aborting debug run." >&2
          return 1
        fi
      done
      ;;
    group)
      shift
      if [[ -z "$1" ]]; then
        echo "Usage: migrate group <g1,g2,...>"
        return 1
      fi
      echo "Running custom groups: $1"
      docker exec -it "$container" php artisan migrate-all --groups="$1"
      ;;
    status)
      docker exec -it "$container" php artisan migrate:status
      ;;
    tinker)
      shift
      docker exec -it "$container" php artisan tinker "$@"
      ;;
    customers)
      docker exec -it "$container" php artisan migrate --path=database/migrations/customers ;;
    config)
      docker exec -it "$container" php artisan migrate --path=database/migrations/config ;;
    shared|sharedstorage)
      docker exec -it "$container" php artisan migrate --path=database/migrations/sharedStorage ;;
    rollback)
      local target="${2:-customers}"
      case "$target" in
        customers) docker exec -it "$container" php artisan migrate:rollback --path=database/migrations/customers ;;
        config) docker exec -it "$container" php artisan migrate:rollback --path=database/migrations/config ;;
        shared|sharedstorage) docker exec -it "$container" php artisan migrate:rollback --path=database/migrations/sharedStorage ;;
        *) echo "Invalid rollback target: $target"; return 1 ;;
      esac
      ;;
    help|-h|--help)
      cat <<'EOF'
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
      return 0 ;;
    *)
      echo "Invalid migrate option: $action" >&2
      echo "Run: migrate help" >&2
      return 1 ;;
  esac
}

# Nuke tool (destructive client cleanup) -- requires explicit ENABLE_NUKE or prompt confirmation
nuke() {
  # Optional additional guard: require ENABLE_NUKE env var; comment out to disable
  if [[ -z "${ENABLE_NUKE:-}" ]]; then
    echo "Refusing to run: set ENABLE_NUKE=1 to allow nuke (export ENABLE_NUKE=1)" >&2
    return 99
  fi

  #######################################
  # DANGEROUS multi-tenant cleanup tool; drops databases & rows.
  # Arguments:
  #   [--verify|-v] (optional) perform analysis only
  #   [--help|-h]   show usage
  #   [clientName]  target client (otherwise interactive picker)
  # Globals:
  #   DB_USERNAME, DB_PASSWORD, DB_SERVICES_HOST, NUKE_CONFIG_DB (optional overrides)
  # Outputs:
  #   Human-readable analysis to STDOUT; warnings/errors to STDERR
  # Returns:
  #   0 on success / safe aborts; >0 on errors
  #######################################

  err() { printf 'ERROR: %s\n' "$*" >&2; }
  warn() { printf 'WARN: %s\n' "$*" >&2; }
  info() { printf '%s\n' "$*"; }
  usage() {
    cat <<'EOF'
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
    local prompt expected reply
    prompt=$1 expected=$2
    printf '%s' "$prompt" >&2
    read -r reply || return 1
    [[ "$reply" == "$expected" ]]
  }

  local mode="normal" target="" container settings_table="00_settings"
  local -r BLACKLIST_REGEX='^(prod|production|shared|sharedstorage|system|default|oci)$'
  local -r MASTER_BLACKLIST_PATTERN='^(proactive_accounts\.ini|spend-cloud|oci)$'

  # Colors (disable if NO_COLOR or not a TTY)
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    local -r COLOR_RED=$'\e[0;31m' COLOR_GREEN=$'\e[0;32m' COLOR_YELLOW=$'\e[1;33m' COLOR_CYAN=$'\e[0;36m' COLOR_NONE=$'\e[0m'
  else
    local -r COLOR_RED="" COLOR_GREEN="" COLOR_YELLOW="" COLOR_CYAN="" COLOR_NONE=""
  fi

  : "${DB_USERNAME:=root}" "${DB_PASSWORD:=}" "${DB_SERVICES_HOST:=mysql-service}" "${NUKE_CONFIG_DB:=spend-cloud-config}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verify|-v) mode="verify"; shift ;;
      --help|-h) usage; return 0 ;;
      --) shift; break ;;
      -*) err "Unknown flag: $1"; usage; return 2 ;;
      *) if [[ -z "$target" ]]; then target=$1; else err "Unexpected extra arg: $1"; return 2; fi; shift ;;
    esac
  done

  container=$(docker ps --format '{{.Names}}' | grep -E '^spend-cloud-api$' | head -1)
  if [[ -z "$container" ]]; then
    err "API container not running"; return 3
  fi

  local -a MYSQL_BASE=(docker exec -i "$container" mysql -u"$DB_USERNAME" -h "$DB_SERVICES_HOST" "$NUKE_CONFIG_DB")
  if [[ -n "$DB_PASSWORD" ]]; then
    MYSQL_BASE=(docker exec -i "$container" mysql -u"$DB_USERNAME" -p"$DB_PASSWORD" -h "$DB_SERVICES_HOST" "$NUKE_CONFIG_DB")
  fi
  _sql() { "${MYSQL_BASE[@]}" -N -e "$1" 2>/dev/null; }

  if _sql "SHOW TABLES LIKE 'client_settings'" | grep -q '^client_settings$'; then
    settings_table='client_settings'
  fi

  if ! _sql "SHOW COLUMNS FROM ${settings_table} LIKE '043'" >/dev/null; then
    warn "Column '043' not found in ${settings_table}. Cannot map client names reliably."
    warn "Falling back to folder and 00_client derived names only."
  fi

  local folder_clients settings_clients table_clients all_candidates filtered client_table_col
  folder_clients=$(docker exec "$container" bash -lc 'ls -1 /data 2>/dev/null | grep -Ev "^(test|lost\+found)$"' || true)
  settings_clients=$(_sql "SELECT DISTINCT \`043\` FROM ${settings_table} WHERE \`043\` IS NOT NULL AND \`043\` != ''" | tr '[:upper:]' '[:lower:]' || true)
  if [[ -n "$client_table_col" ]]; then
    table_clients=$(_sql "SELECT DISTINCT ${client_table_col} FROM 00_client WHERE ${client_table_col} IS NOT NULL AND ${client_table_col} != ''" | tr '[:upper:]' '[:lower:]')
  fi
  all_candidates=$(printf '%s\n%s\n%s\n' "$folder_clients" "$settings_clients" "$table_clients" | awk 'NF' | sort -u)
  filtered=$(echo "$all_candidates" | grep -Ev "$MASTER_BLACKLIST_PATTERN" || true)
  if [[ -z "$filtered" ]]; then
    warn "No eligible clients to operate on (after blacklist & data sources)."
    return 0
  fi

  if [[ -z "$target" ]]; then
    if command -v fzf >/dev/null 2>&1; then
      target=$(echo "$filtered" | fzf --prompt="Select client > ")
    else
      info "${COLOR_CYAN}Select client:${COLOR_NONE}" >&2
      local selection i=1 choice
      readarray -t selection <<<"$filtered"
      for choice in "${selection[@]}"; do printf '%2d) %s\n' "$i" "$choice" >&2; ((i++)); done
      printf 'Enter number: ' >&2
      local num; read -r num
      if [[ "$num" =~ ^[0-9]+$ ]] && (( num >=1 && num < i )); then target=${selection[num-1]}; fi
    fi
    if [[ -z "$target" ]]; then
      warn "No client selected"; return 0
    fi
  fi

  if [[ "$target" =~ $BLACKLIST_REGEX ]]; then err "Target '$target' is protected"; return 4; fi
  if ! echo "$filtered" | grep -Fx "$target" >/dev/null; then err "Target '$target' not in candidate list"; return 5; fi

  local client_id has_folder=0 has_settings=0 has_client_row=0 dbs
  dbs=$(_sql "SHOW DATABASES" | grep -i "$target" | grep -Ev '^(information_schema|mysql|performance_schema|sys)$' || true)
  if [[ -n "$client_table_col" ]]; then
    client_id=$(_sql "SELECT id FROM 00_client WHERE LOWER(${client_table_col})=LOWER('$target') LIMIT 1")
  fi
  if echo "$folder_clients" | grep -Fx "$target" >/dev/null; then has_folder=1; fi
  if echo "$settings_clients" | grep -Fx "$target" >/dev/null; then has_settings=1; fi
  if [[ -n "$client_id" ]]; then has_client_row=1; fi

  info "${COLOR_CYAN}Analysis for '$target':${COLOR_NONE}"
  printf '  - /data folder: %s\n'  "$( [[ $has_folder -eq 1 ]] && echo present || echo absent )"
  printf '  - %s entry (col 043): %s\n' "$settings_table" "$( [[ $has_settings -eq 1 ]] && echo present || echo absent )"
  printf '  - 00_client row: %s\n'  "$( [[ $has_client_row -eq 1 ]] && echo present || echo absent )"
  if [[ -n "$dbs" ]]; then
    info '  - databases:'
    while IFS= read -r _db; do printf '      * %s\n' "$_db"; done <<< "$dbs"
  else
    info '  - databases: none'
  fi

  if [[ "$mode" == 'verify' ]]; then
    info "${COLOR_GREEN}Verify mode: no changes made.${COLOR_NONE}"
    return 0
  fi

  if ! confirm "${COLOR_YELLOW}Proceed to NUKE '$target'? (yes/no) ${COLOR_NONE}" 'yes'; then
    info "${COLOR_GREEN}Aborted.${COLOR_NONE}"; return 0
  fi
  if ! confirm "${COLOR_RED}Type the client name to confirm: ${COLOR_NONE}" "$target"; then
    info "${COLOR_GREEN}Mismatch. Aborted.${COLOR_NONE}"; return 1
  fi
  info "${COLOR_RED}Executing NUKE...${COLOR_NONE}"

  if [[ -n "$dbs" ]]; then
    while IFS= read -r db; do
      [[ -z "$db" ]] && continue
      info "  - drop db $db"
      _sql "DROP DATABASE IF EXISTS \`$db\`;" >/dev/null || warn "    (warn) drop failed $db"
    done <<<"$dbs"
  fi

  if (( has_settings == 1 )); then
    info "  - purge ${settings_table}"
    _sql "DELETE FROM ${settings_table} WHERE LOWER(\`043\`)=LOWER('$target')" >/dev/null || warn "    (warn) purge failed"
  fi

  if [[ -n "$client_id" ]]; then
    local related
    related=$(_sql "SELECT table_name FROM information_schema.columns WHERE table_schema=DATABASE() AND column_name='client_id'")
    if [[ -n "$related" ]]; then
      while IFS= read -r t; do
        [[ -z "$t" ]] && continue
        info "    * purge $t"
        _sql "DELETE FROM \`$t\` WHERE client_id=$client_id" >/dev/null || warn "      (warn) rel purge failed $t"
      done <<<"$related"
    fi
    info "  - delete 00_client row"
    _sql "DELETE FROM 00_client WHERE id=$client_id" >/dev/null || warn "    (warn) client row delete failed"
  fi

  if docker exec "$container" test -d "/data/$target"; then
    if docker exec "$container" rm -rf "/data/$target"; then
      info "  - removed /data/$target"
    else
      warn "  - (warn) folder removal failed"
    fi
  fi

  info "${COLOR_GREEN}Done. Run: nuke --verify $target${COLOR_NONE}"
  return 0
}

# SpendCloud PATH blocks & ASDF (if present)
if [[ -f '/home/tom/google-cloud-sdk/path.zsh.inc' ]]; then . '/home/tom/google-cloud-sdk/path.zsh.inc'; fi
if [[ -f '/home/tom/google-cloud-sdk/completion.zsh.inc' ]]; then . '/home/tom/google-cloud-sdk/completion.zsh.inc'; fi
export PATH="${PATH}:/home/tom/google-cloud-sdk/bin"
export PATH="$PATH:$HOME/.composer/vendor/bin"
if command -v yarn >/dev/null 2>&1; then export PATH="$PATH:$(yarn global bin)"; fi
export PATH="$PATH:$HOME/.local/bin"
if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
  # shellcheck disable=SC1091 # optional ASDF environment script (dynamic, may not exist)
  . "$HOME/.asdf/asdf.sh"
fi

# End optional module
