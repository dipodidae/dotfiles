#!/usr/bin/env zsh
#
# Cluster management command for SpendCloud plugin.

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
  cat <<'EOF'
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
