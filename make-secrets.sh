#!/bin/bash
# Bundle and encrypt all secrets into a single age-encrypted archive.
# This is the counterpart to secrets::decrypt_bundle in lib/secrets.sh.
# Run this whenever you update an SSH key or config and want to re-encrypt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/secrets"
MANIFEST="${SECRETS_DIR}/manifest.txt"
BUNDLE="${SECRETS_DIR}/secrets.tar.gz.age"

main() {
  if [[ ! -f "${MANIFEST}" ]]; then
    echo "ERROR: manifest not found at ${MANIFEST}" >&2
    exit 1
  fi

  if ! command -v age &> /dev/null; then
    echo "ERROR: age is not installed" >&2
    exit 1
  fi

  local has_gum=0
  command -v gum &> /dev/null && has_gum=1

  mkdir -p "${SECRETS_DIR}"

  # Collect source files from manifest.
  local -a files=()
  local -a missing=()
  local _label dest _perms
  while IFS=: read -r _label dest _perms; do
    [[ -z "${_label}" || "${_label}" == \#* ]] && continue
    dest="${dest/#\~/${HOME}}"
    if [[ ! -f "${dest}" ]]; then
      missing+=("${dest}")
      continue
    fi
    files+=("${dest}")
  done < "${MANIFEST}"

  local f
  for f in "${missing[@]}"; do
    echo "SKIP: ${f} not found" >&2
  done

  if ((${#files[@]} == 0)); then
    echo "Nothing to encrypt — no source files found." >&2
    exit 1
  fi

  # Show what will be bundled.
  if ((has_gum)); then
    gum style --bold --foreground 212 --border rounded \
      --border-foreground 212 --padding "0 2" \
      "Bundling ${#files[@]} files"
    printf "\n"
    for f in "${files[@]}"; do
      gum style --foreground 78 -- "  • ${f}"
    done
    printf "\n"
  else
    echo "Bundling ${#files[@]} files."
    for f in "${files[@]}"; do
      echo "  • ${f}"
    done
    echo ""
  fi

  # Create tar archive with paths relative to $HOME.
  local tmptar
  tmptar="$(mktemp)"
  trap 'rm -f "${tmptar}"' EXIT

  tar -czf "${tmptar}" -C "${HOME}" \
    "${files[@]/#${HOME}\//}"

  # Encrypt with age.
  if ((has_gum)); then
    local passphrase confirm
    passphrase="$(
      gum input --password \
        --placeholder "Enter passphrase" \
        --prompt "🔑 " --prompt.foreground 212
    )"
    confirm="$(
      gum input --password \
        --placeholder "Confirm passphrase" \
        --prompt "🔑 " --prompt.foreground 212
    )"
    if [[ "${passphrase}" != "${confirm}" ]]; then
      gum style --foreground 196 -- "  ✖ Passphrases do not match"
      exit 1
    fi
    printf '%s' "${passphrase}" |
      age -p -o "${BUNDLE}" "${tmptar}" 2> /dev/null
  else
    echo "Enter passphrase for age encryption:"
    age -p -o "${BUNDLE}" "${tmptar}"
  fi

  # Clean up old per-file .age files.
  local label
  while IFS=: read -r label _dest _perms; do
    [[ -z "${label}" || "${label}" == \#* ]] && continue
    rm -f "${SECRETS_DIR}/${label}"
  done < "${MANIFEST}"

  # Done.
  if ((has_gum)); then
    printf "\n"
    gum style --bold --foreground 78 --border rounded \
      --border-foreground 78 --padding "0 2" \
      "✔ Created: secrets/secrets.tar.gz.age"
    printf "\n"
    gum style --faint \
      -- "  Commit: git add secrets/ && git commit"
  else
    echo ""
    echo "✔ Created: ${BUNDLE}"
    echo "Commit: git add secrets/ && git commit"
  fi
}

main "$@"
