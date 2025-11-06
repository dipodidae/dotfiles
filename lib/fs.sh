#!/bin/bash
# Filesystem helpers for the installer.
# shellcheck shell=bash

#######################################
# fs::backup
# Copy file/directory into BACKUP_DIR if it exists.
# Globals:
#   BACKUP_DIR
#######################################
fs::backup() {
  local path="$1"
  [[ -e "${path}" ]] || return 0
  core::run mkdir -p "${BACKUP_DIR}"
  if core::run cp -a "${path}" "${BACKUP_DIR}/"; then
    note "Backup: $(basename "${path}")"
  else
    warn "Backup failed: ${path}"
  fi
}

#######################################
# fs::ensure_symlink
# Create symlink if destination absent or points elsewhere.
# Removes existing non-symlink files (caller should backup first).
# Globals:
#   DRY_RUN
# Arguments:
#   1 - source path
#   2 - destination path
# Returns:
#   0 on success, 1 on failure
#######################################
fs::ensure_symlink() {
  local src="$1" dest="$2"
  core::run mkdir -p "$(dirname "${dest}")"

  # If destination is already a symlink pointing to the correct source, done
  if [[ -L "${dest}" ]]; then
    local current_target
    current_target="$(readlink "${dest}")"
    if [[ "${current_target}" == "${src}" ]]; then
      return 0
    fi
    # Symlink exists but points elsewhere; remove it
    if [[ "${DRY_RUN}" == "1" ]]; then
      note "(dry-run) rm ${dest} (wrong target: ${current_target})"
    else
      rm -f "${dest}"
    fi
  elif [[ -e "${dest}" ]]; then
    # Destination exists but is not a symlink; caller should have backed it up
    if [[ "${DRY_RUN}" == "1" ]]; then
      note "(dry-run) rm ${dest} (not a symlink)"
    else
      rm -f "${dest}"
    fi
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) ln -s ${src} ${dest}"
    return 0
  fi
  ln -s "${src}" "${dest}"
}

#######################################
# fs::append_once
# Append a line to a file if it is not already present.
#######################################
fs::append_once() {
  local file="$1" line="$2"
  if grep -qxF "${line}" "${file}" 2> /dev/null; then
    return 1
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    note "(dry-run) append '${line}' to ${file}"
    return 0
  fi
  printf '%s\n' "${line}" >> "${file}"
}

#######################################
# fs::ensure_dir
# Ensure a directory exists.
#######################################
fs::ensure_dir() {
  core::run mkdir -p "$1"
}
