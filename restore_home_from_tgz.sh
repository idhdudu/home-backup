#!/usr/bin/env bash

set -u
set -o pipefail

# Easy to edit.
ARCHIVE_DIR_BASE="/root/home_restore_incoming"
LOCAL_BASE="/home"
DAY_SLOT="$(date +%u)"
ARCHIVE_DIR_SLOT="${ARCHIVE_DIR_BASE}/${DAY_SLOT}"

umask 077

if [[ ! -d "$LOCAL_BASE" ]]; then
  echo "ERROR: local base path does not exist: $LOCAL_BASE" >&2
  exit 1
fi

shopt -s nullglob

ARCHIVE_DIR=""
archives=()

for candidate in "$ARCHIVE_DIR_SLOT" "$ARCHIVE_DIR_BASE"; do
  [[ -d "$candidate" ]] || continue
  candidate_archives=("$candidate"/*.tgz)
  if [[ ${#candidate_archives[@]} -gt 0 ]]; then
    ARCHIVE_DIR="$candidate"
    archives=("${candidate_archives[@]}")
    break
  fi
done

if [[ ${#archives[@]} -eq 0 ]]; then
  echo "No .tgz archives found in $ARCHIVE_DIR_SLOT or $ARCHIVE_DIR_BASE"
  exit 0
fi

echo "Restoring archives from $ARCHIVE_DIR to $LOCAL_BASE"

read -r -p "This will overwrite existing files under $LOCAL_BASE. Continue? [y/N] " answer
case "$answer" in
  y|Y|yes|YES)
    ;;
  *)
    echo "Aborted by user."
    exit 0
    ;;
esac

for archive in "${archives[@]}"; do
  name="$(basename "$archive")"
  echo "Restoring: $name"

  if tar -C "$LOCAL_BASE" \
    --acls \
    --xattrs \
    --selinux \
    --numeric-owner \
    -xpf "$archive"; then
    echo "Done: $name"
  else
    echo "ERROR: failed to restore $name" >&2
  fi
done

