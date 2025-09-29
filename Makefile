# Dotfiles Makefile
# Provides convenient commands for maintaining shell scripts

.PHONY: format format-check format-dry help install lint audit

# Default target
help:
	@echo "Available commands:"
	@echo "  make format      - Format all shell files with 2-space indentation"
	@echo "  make format-dry  - Preview formatting changes without applying"
	@echo "  make format-check- Check if files need formatting (exit 1 if needed)"
	@echo "  make lint        - Run shellcheck on all shell files"
	@echo "  make audit       - Run style audit (Google Shell Style Guide)"
	@echo "  make install     - Run the dotfiles installer"
	@echo ""
	@echo "Options for format commands:"
	@echo "  QUIET=1         - Suppress non-essential output"
	@echo "  FORCE=1         - Format even clean files"

# Format all shell files
format:
	@./scripts/format-simple.sh

# Preview formatting changes
format-dry:
	@./scripts/format-simple.sh --dry-run

# Check if formatting is needed (for CI/git hooks)
format-check:
	@if ./scripts/format-simple.sh --dry-run | grep -q "needs formatting"; then \
		echo "Files need formatting. Run 'make format' to fix."; \
		exit 1; \
	else \
		echo "All files properly formatted."; \
	fi

# Run shellcheck
lint:
	@./scripts/lint-shell.sh

# Run style audit
audit:
	@./scripts/audit-shell-style.sh

# Run installer
install:
	@./install.sh

# Git pre-commit hook helper
pre-commit: format-check lint
