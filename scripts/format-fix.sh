#!/usr/bin/env bash
#
# Enhanced shell formatting tool with better feedback and options
# Enforces 2-space indentation and Google Shell Style Guide formatting

set -euo pipefail

# Configuration
readonly INDENT_SIZE=2
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly RED='\033[31m'
  readonly GREEN='\033[32m'
  readonly YELLOW='\033[33m'
  readonly BLUE='\033[34m'
  readonly CYAN='\033[36m'
  readonly BOLD='\033[1m'
  readonly RESET='\033[0m'
else
  readonly RED=""
  readonly GREEN=""
  readonly YELLOW=""
  readonly BLUE=""
  readonly CYAN=""
  readonly BOLD=""
  readonly RESET=""
fi

#######################################
# Print usage information
#######################################
usage() {
  cat <<EOF
${BOLD}Usage:${RESET} $(basename "$0") [OPTIONS]

${BOLD}DESCRIPTION:${RESET}
  Enforce consistent 2-space indentation and shell formatting across all
  shell files in the project using shfmt and ShellCheck.

${BOLD}OPTIONS:${RESET}
  -d, --dry-run    Show what would be changed without modifying files
  -q, --quiet      Suppress non-essential output
  -f, --force      Format files even if they appear clean
  -h, --help       Show this help message

${BOLD}EXAMPLES:${RESET}
  $(basename "$0")              # Format all shell files
  $(basename "$0") --dry-run    # Preview changes without applying
  $(basename "$0") --quiet      # Run silently (good for git hooks)

${BOLD}NOTE:${RESET}
  This tool uses shfmt with -i ${INDENT_SIZE} to enforce ${INDENT_SIZE}-space indentation.
  Review changes with: ${CYAN}git diff${RESET}
EOF
}

#######################################
# Print colored status messages
# Arguments:
#   $1 - message type (info, success, warning, error)
#   $2 - message text
#######################################
log() {
  local type="$1" message="$2"
  case "$type" in
    info)    printf "%s[INFO]%s %s\n" "$BLUE" "$RESET" "$message" ;;
    success) printf "%s[✓]%s %s\n" "$GREEN" "$RESET" "$message" ;;
    warning) printf "%s[!]%s %s\n" "$YELLOW" "$RESET" "$message" ;;
    error)   printf "%s[✗]%s %s\n" "$RED" "$RESET" "$message" >&2 ;;
  esac
}

#######################################
# Find all shell files in the project
# Outputs:
#   Array of shell file paths
#######################################
find_shell_files() {
  local files=()

  cd "$ROOT_DIR"

  # Git-tracked .sh files
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(git ls-files -z '*.sh' 2>/dev/null || true)

  # Special files
  [[ -f .zshrc ]] && files+=(".zshrc")

  # Additional zsh files
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find .zsh -type f -name '*.zsh' -print0 2>/dev/null || true)

  # Output files (handle empty array)
  if [[ ${#files[@]} -gt 0 ]]; then
    printf '%s\n' "${files[@]}"
  fi
}

#######################################
# Check if shfmt needs to make changes to a file
# Arguments:
#   $1 - file path
# Returns:
#   0 if file needs formatting, 1 if already formatted
#######################################
needs_formatting() {
  local file="$1"
  if ! command -v shfmt >/dev/null 2>&1; then
    return 0  # Assume it needs formatting if we can't check
  fi

  # Compare current content with what shfmt would produce
  if shfmt -i "$INDENT_SIZE" -ci -sr "$file" | cmp -s "$file" -; then
    return 1  # No changes needed
  else
    return 0  # Changes needed
  fi
}

#######################################
# Main formatting function
# Arguments:
#   --dry-run: preview mode
#   --quiet: suppress output
#   --force: format even if files appear clean
#######################################
main() {
  local dry_run=false quiet=false force=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d|--dry-run) dry_run=true; shift ;;
      -q|--quiet) quiet=true; shift ;;
      -f|--force) force=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) log error "Unknown option: $1"; usage >&2; exit 1 ;;
    esac
  done

  # Check dependencies
  if ! command -v shfmt >/dev/null 2>&1; then
    log error "shfmt not found. Install with: sudo apt install shfmt"
    exit 1
  fi

  # Find shell files
  mapfile -t shell_files < <(find_shell_files)

  if [[ ${#shell_files[@]} -eq 0 ]]; then
    [[ $quiet == false ]] && log warning "No shell files found"
    exit 0
  fi

  [[ $quiet == false ]] && log info "Found ${#shell_files[@]} shell files"

  # Check which files need formatting
  local files_to_format=()
  local already_formatted=0

  for file in "${shell_files[@]}"; do
    if [[ $force == true ]] || needs_formatting "$file"; then
      files_to_format+=("$file")
    else
      ((already_formatted++))
    fi
  done

  # Report status
  if [[ $quiet == false ]]; then
    if [[ ${#files_to_format[@]} -eq 0 ]]; then
      log success "All ${#shell_files[@]} files already properly formatted!"
      exit 0
    fi

    log info "${#files_to_format[@]} files need formatting, $already_formatted already clean"
  fi

  # Show what would be changed in dry-run mode
  if [[ $dry_run == true ]]; then
    [[ $quiet == false ]] && log info "DRY RUN - Files that would be formatted:"
    printf "%s\n" "${files_to_format[@]}"
    exit 0
  fi

  # Format files
  [[ $quiet == false ]] && log info "Formatting with shfmt -i $INDENT_SIZE -ci -sr..."

  if shfmt -w -i "$INDENT_SIZE" -ci -sr "${files_to_format[@]}"; then
    [[ $quiet == false ]] && log success "Formatted ${#files_to_format[@]} files"
  else
    log error "shfmt encountered errors"
    exit 1
  fi

  # Run shellcheck if available (advisory only)
  if command -v shellcheck >/dev/null 2>&1 && [[ $quiet == false ]]; then
    log info "Running ShellCheck (advisory)..."
    local shellcheck_failed=0
    for file in "${files_to_format[@]}"; do
      if ! shellcheck "$file" 2>/dev/null; then
        ((shellcheck_failed++))
      fi
    done

    if [[ $shellcheck_failed -gt 0 ]]; then
      log warning "ShellCheck found issues in $shellcheck_failed files (not blocking)"
    else
      log success "ShellCheck passed for all formatted files"
    fi
  fi

  # Final status
  if [[ $quiet == false ]]; then
    log success "Formatting complete! Review changes with: ${CYAN}git diff${RESET}"
  fi
}

main "$@"
