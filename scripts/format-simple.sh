#!/usr/bin/env bash
#
# Simple shell formatter - enforces 2-space indentation project-wide

set -euo pipefail

# Colors
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED='\033[31m' GREEN='\033[32m' YELLOW='\033[33m'
  BLUE='\033[34m' CYAN='\033[36m' BOLD='\033[1m' RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
fi

log() {
  case "$1" in
    info) printf "%b[INFO]%b %s\n" "$BLUE" "$RESET" "$2" ;;
    ok) printf "%b[✓]%b %s\n" "$GREEN" "$RESET" "$2" ;;
    warn) printf "%b[!]%b %s\n" "$YELLOW" "$RESET" "$2" ;;
    error) printf "%b[✗]%b %s\n" "$RED" "$RESET" "$2" >&2 ;;
  esac
}

# Check if shfmt is available
if ! command -v shfmt >/dev/null 2>&1; then
  log error "shfmt not found. Install with: sudo apt install shfmt"
  exit 1
fi

# Find shell files
files=()
cd "$(dirname "$0")/.."

# Git tracked .sh files
while IFS= read -r file; do
  [[ -n "$file" ]] && files+=("$file")
done < <(git ls-files '*.sh' 2>/dev/null || true)

# Special files
[[ -f .zshrc ]] && files+=(".zshrc")

# ZSH files
while IFS= read -r file; do
  [[ -n "$file" ]] && files+=("$file")
done < <(find .zsh -type f -name '*.zsh' 2>/dev/null || true)

if [[ ${#files[@]} -eq 0 ]]; then
  log warn "No shell files found"
  exit 0
fi

log info "Found ${#files[@]} shell files"

# Handle dry-run
if [[ "${1:-}" == "--dry-run" ]]; then
  log info "DRY RUN - Files that would be checked/formatted:"
  for file in "${files[@]}"; do
    if ! shfmt -i 2 -ci -sr "$file" | cmp -s "$file" -; then
      echo "  $file (needs formatting)"
    else
      echo "  $file (already formatted)"
    fi
  done
  exit 0
fi

# Format files
log info "Formatting ${#files[@]} files with 2-space indentation..."
if shfmt -w -i 2 -ci -sr "${files[@]}"; then
  log ok "Formatting complete!"
  log info "Review changes with: ${CYAN}git diff${RESET}"
else
  log error "Formatting failed"
  exit 1
fi
