# Dotfiles Makefile
# Simple interface to canonical linting pipeline (matches GitHub Actions)

.PHONY: help install lint

# Default target
help:
	@echo "Available commands:"
	@echo "  make lint     - Run complete shell lint (shellcheck + shfmt + audit)"
	@echo "  make install  - Run the dotfiles installer"
	@echo ""
	@echo "For formatting: use 'shfmt -i 2 -ci -sr -w .' or let pre-commit handle it"

# Run complete lint suite (matches GitHub Actions)
lint:
	@./scripts/lint-shell.sh

# Run installer
install:
	@./install.sh
