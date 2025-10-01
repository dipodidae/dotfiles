#!/usr/bin/env zsh
#
# Database migration command for SpendCloud plugin.


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
    IFS=',' read -r -A groups <<<"${cleaned}"
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
  IFS=' ' read -r -A groups <<<"$(_migrate_get_groups)"
  echo "Running grouped migrations in order: ${groups[*]}"
  _migrate_exec "${container}" migrate-all --groups="$(
    IFS=,
    echo "${groups[*]}"
  )"
}

_migrate_debug() {
  local container="${1}"
  local -a groups
  IFS=' ' read -r -A groups <<<"$(_migrate_get_groups)"
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
  tinker)
    shift
    _migrate_exec "${container}" tinker "$@"
    ;;
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
