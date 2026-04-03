#!/bin/bash
# Encrypt all files listed in secrets/manifest.txt using age passphrase encryption.
# This is the counterpart to secrets::decrypt_all in lib/secrets.sh.
# Run this whenever you update an SSH key or config and want to re-encrypt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/secrets"
MANIFEST="${SECRETS_DIR}/manifest.txt"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "ERROR: manifest not found at ${MANIFEST}" >&2
  exit 1
fi

if ! command -v age &>/dev/null; then
  echo "ERROR: age is not installed (https://github.com/FiloSottile/age)" >&2
  exit 1
fi

mkdir -p "${SECRETS_DIR}"

# Collect entries from manifest, check source files exist.
declare -a entries=()
while IFS=: read -r encrypted dest _perms; do
  [[ -z "${encrypted}" || "${encrypted}" == \#* ]] && continue
  dest="${dest/#\~/${HOME}}"
  if [[ ! -f "${dest}" ]]; then
    echo "SKIP: ${dest} not found" >&2
    continue
  fi
  entries+=("${encrypted}:${dest}")
done < "${MANIFEST}"

if (( ${#entries[@]} == 0 )); then
  echo "Nothing to encrypt — no source files found." >&2
  exit 1
fi

echo "Encrypting ${#entries[@]} files from manifest."
echo "age will prompt for your passphrase for each file (use the same one!)."
echo ""

failed=0
count=0
for entry in "${entries[@]}"; do
  encrypted="${entry%%:*}"
  src="${entry#*:}"
  out="${SECRETS_DIR}/${encrypted}"

  echo "--- ${src} → ${encrypted}"
  if age -p -o "${out}" "${src}"; then
    echo "  OK"
    (( count++ )) || true
  else
    echo "  FAILED" >&2
    failed=1
  fi
done

echo ""
echo "Encrypted ${count}/${#entries[@]} files."
exit "${failed}"
