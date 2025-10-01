#!/bin/bash
#
# Setup git hook for automatic shell formatting checks

set -Eeuo pipefail

#######################################
# Main function to set up git pre-commit hook
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes setup status to stdout
# Returns:
#   0 on success
#######################################
main() {
  cd "$(git rev-parse --show-toplevel)"

  if [[ -f .git/hooks/pre-commit ]]; then
    echo "Pre-commit hook already exists. Creating backup..."
    cp .git/hooks/pre-commit .git/hooks/pre-commit.backup
  fi

  echo "Installing pre-commit hook..."
  ln -sf ../../scripts/pre-commit-hook .git/hooks/pre-commit

  echo "✅ Pre-commit hook installed!"
  echo ""
  echo "Now your commits will automatically check shell formatting."
  echo "To remove: rm .git/hooks/pre-commit"
}

main "$@"
