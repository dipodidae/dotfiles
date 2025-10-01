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
#   Functions: cluster cluster-import migrate nuke
#
# Refactored using clean code principles: DRY, SRP, meaningful names, small functions.
# Modular architecture: each command is in its own file under lib/

# Guard against duplicate loading
if [[ -n "${_SPEND_CLOUD_PLUGIN_LOADED:-}" ]]; then
  return 0
fi
readonly _SPEND_CLOUD_PLUGIN_LOADED=1

# Get the directory where this plugin is located
typeset -g SPEND_CLOUD_PLUGIN_DIR="${${(%):-%x}:A:h}"

# Load modules in dependency order
source "${SPEND_CLOUD_PLUGIN_DIR}/lib/common.zsh"      # Common utilities and constants
source "${SPEND_CLOUD_PLUGIN_DIR}/lib/docker.zsh"      # Docker container management
source "${SPEND_CLOUD_PLUGIN_DIR}/lib/aliases.zsh"     # Navigation aliases
source "${SPEND_CLOUD_PLUGIN_DIR}/lib/cluster.zsh"     # Cluster lifecycle management
source "${SPEND_CLOUD_PLUGIN_DIR}/lib/cluster-import.zsh"  # Cluster import command
source "${SPEND_CLOUD_PLUGIN_DIR}/lib/migrate.zsh"     # Database migration command
source "${SPEND_CLOUD_PLUGIN_DIR}/lib/nuke.zsh"        # Client cleanup tool
