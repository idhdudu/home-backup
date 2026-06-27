#!/usr/bin/env bash

set -u
set -o pipefail

# Easy to edit.
REMOTE_HOST="SERVER"
REMOTE_PORT="PORT"
REMOTE_USER="USER"
SYSTEM_HOSTNAME="${HOSTNAME:-}"
if [[ -z "$SYSTEM_HOSTNAME" ]]; then
  SYSTEM_HOSTNAME="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"
fi
if [[ -z "$SYSTEM_HOSTNAME" ]]; then
  SYSTEM_HOSTNAME="SERVER_NAME"
fi
REMOTE_PATH="/volume1/${SYSTEM_HOSTNAME}/home"
LOCAL_BASE="/home"
DAY_SLOT="$(date +%u)"
REMOTE_SLOT_PATH="${REMOTE_PATH}/${DAY_SLOT}"

umask 077

if [[ ! -d "$LOCAL_BASE" ]]; then
  echo "ERROR: local base path does not exist: $LOCAL_BASE" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d /tmp/home_backup.XXXXXX)"

cleanup() {
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

if ! ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p -- '$REMOTE_SLOT_PATH'"; then
  echo "ERROR: could not create remote path: $REMOTE_SLOT_PATH" >&2
  exit 1
fi

echo "Starting backup from $LOCAL_BASE to $REMOTE_USER@$REMOTE_HOST:$REMOTE_SLOT_PATH"

found_any=0

for dir in "$LOCAL_BASE"/*; do
  [[ -d "$dir" ]] || continue
  found_any=1

  name="$(basename "$dir")"
  archive="$WORK_DIR/${name}.tgz"

  echo "Packing: $name"
  if ! tar -C "$LOCAL_BASE" \
    --ignore-failed-read \
    --acls \
    --xattrs \
    --selinux \
    --numeric-owner \
    -czf "$archive" "$name"; then
    echo "ERROR: tar failed for $dir" >&2
    rm -f "$archive"
    continue
  fi

  echo "Sending: $name"
  if rsync -avz -e "ssh -p $REMOTE_PORT" -- "$archive" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_SLOT_PATH/"; then
    rm -f "$archive"
    echo "Done: $name"
  else
    echo "ERROR: rsync failed for $name; archive kept at $archive" >&2
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "No directories found inside $LOCAL_BASE"
fi
