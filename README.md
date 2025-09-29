## dotfiles

Lean, repeatable developer shell bootstrap (Zsh + Node + modern CLI tooling) with sane defaults and fast idempotent re-runs.

### Quick install (remote)
```bash
curl -fsSL https://raw.githubusercontent.com/dipodidae/dotfiles/main/install.sh | bash
```

### Manual clone (local / symlink mode)
```bash
git clone https://github.com/dipodidae/dotfiles.git
cd dotfiles && ./install.sh
```

### What's included (auto-installed where possible)
- Zsh + Oh My Zsh + Pure prompt
- Zsh plugins: autosuggestions, syntax highlighting, z, you-should-use
- Git + handy aliases + hub -> gh alias (if hub missing)
- GitHub CLI (gh)
- NVM + Node LTS
- JS tooling: pnpm, ni (nr / nx / nu / nun), diff-so-fancy
- fzf + integration helpers (fd / bat / tree when packages available)
- pyenv + latest Python (best effort; skips silently if deps missing)
- glow (markdown viewer) for in-terminal help (if available)
- Safe backups of replaced dotfiles to `~/.dotfiles-backup-*`
- Clean, minimal color logging to `~/.dotfiles-install.log`

# dotfiles

![Shell Lint](https://github.com/OWNER/REPO/actions/workflows/shellcheck.yml/badge.svg)

> Opinionated shell environment with unified lint + formatting and heuristic style audits.

## Shell style / lint

We enforce a pragmatic subset of the Google Shell Style Guide through:

| Layer | Tool | Purpose |
|-------|------|---------|
| Static analysis | ShellCheck | Safety + style warnings (config in `.shellcheckrc`) |
| Formatting | shfmt | Consistent whitespace & indentation (`.shfmt.conf`) |
| Heuristic rules | `scripts/audit-shell-style.sh` | Function headers, main() pattern, size hints |
| Pre-commit | `pre-commit` | Local gate to avoid CI churn |
| CI | GitHub Actions | Re-validates all of the above on push / PR |

### Quick start

Bootstrap lint tooling (assumes shellcheck + shfmt installed or managed by CI):

```
pre-commit install --install-hooks
```

Run full local suite (format, lint, heuristic checks):

```
scripts/fix-shell.sh   # shfmt + advisory shellcheck
scripts/lint-shell.sh  # strict shellcheck (fails on issues)
scripts/audit-shell-style.sh # header + main heuristics
```

### Heuristic audit

`scripts/audit-shell-style.sh` covers style elements not directly enforced by ShellCheck:

* Missing function header blocks (expects a `#######################################` divider above definitions)
* Large scripts (>120 lines) should define `main()` and invoke it at end
* Oversized scripts (>400 lines) reported for potential refactor

Exit status is non‑zero if mandatory heuristics fail (missing headers / main). Oversize warnings do not fail the job.

### ShellCheck configuration

Central flags live in `.shellcheckrc`, consumed uniformly by:

* CI workflow (`.github/workflows/shellcheck.yml`)
* `scripts/lint-shell.sh` / `scripts/fix-shell.sh`
* Pre-commit hook execution

Disabled rules (documented rationale):

| Rule | Rationale |
|------|-----------|
| SC1071 | Mixed shebang vs. sourcing context (zsh + bash) |
| SC1090/SC1091 | Dynamic local sourcing patterns |
| SC2034 | Intentional exported / documented vars |
| SC2086 | Reviewed intentional word splitting |
| SC2119/SC2120 | Flexible no-arg function signatures |
| SC2155 | Concise declare+assign when safe |
| SC2164 | Manual `cd` error handling in critical spots |
| SC2207 | Prefer explicit array capture clarity sometimes |

Zsh files are linted in bash mode for broad issues; failures there are advisory only.

### Formatting

`.shfmt.conf` pins formatting style (indent=2, switch case indent, simplify redirects). Run `shfmt -w .` (or rely on `scripts/fix-shell.sh`).

### Pre-commit

Install & run:

```
pre-commit install
pre-commit run --all-files
```

Update hooks:

```
pre-commit autoupdate
```

### CI badge note

Replace `OWNER/REPO` in the badge URL above after cloning or forking.

### Contributing

1. Keep functions small and documented.
2. Prefer `set -euo pipefail` in standalone scripts; interactive shells may relax pieces thoughtfully.
3. When disabling a ShellCheck rule inline, add a trailing comment why.

### Roadmap (optional niceties)

* Add metrics script (counts functions / lines trend)
* Optional severity split job (info vs style vs warning)
* Shell snippet test harness for critical helpers

---

Feel free to cherry-pick components if you only want the lint tooling.
| pyenv Python missing | Ensure build deps installed, then `pyenv install <version>` |

### Self-test
The script runs a lightweight self-test (core binaries + .zshrc presence). You can manually rerun key checks:
```bash
command -v zsh git curl gh fzf node || echo "Missing some tools"
```

### Logs
`~/.dotfiles-install.log` – append-only, safe to delete between runs.

### Shell style / lint
All shell scripts target Bash (installer) or Zsh (interactive config) and are kept clean with ShellCheck.

Run lint locally:
```bash
shellcheck install.sh
shellcheck ~/.zshrc   # accepts zsh patterns; suppressions embedded
```
Guiding principles follow the Google Shell Style Guide: quoting, [[ ]] tests, avoiding eval, using "$(...)" substitution, and explicit error handling.

### License
MIT

### TL;DR
Run the one-liner, `exec zsh`, then `help`.
