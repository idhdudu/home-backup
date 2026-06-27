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
REMOTE_PATH="/volume1/${SYSTEM_HOSTNAME}/bd"
BACKUP_DIR="/tmp"
DAY_SLOT="$(date +%u)"
REMOTE_SLOT_PATH="${REMOTE_PATH}/${DAY_SLOT}"

# Optional. If empty, mysqldump/mariadb-dump will use the local auth method
# available to the current user (for example, root over unix socket auth).
MYSQL_DEFAULTS_FILE=""

umask 077

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "ERROR: backup dir does not exist: $BACKUP_DIR" >&2
  exit 1
fi

if command -v mariadb-dump >/dev/null 2>&1; then
  DUMP_CMD="mariadb-dump"
elif command -v mysqldump >/dev/null 2>&1; then
  DUMP_CMD="mysqldump"
else
  echo "ERROR: neither mariadb-dump nor mysqldump is available" >&2
  exit 1
fi

if command -v mariadb >/dev/null 2>&1; then
  CLIENT_CMD="mariadb"
elif command -v mysql >/dev/null 2>&1; then
  CLIENT_CMD="mysql"
else
  echo "ERROR: neither mariadb nor mysql is available" >&2
  exit 1
fi

if ! ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p -- '$REMOTE_SLOT_PATH'"; then
  echo "ERROR: could not create remote path: $REMOTE_SLOT_PATH" >&2
  exit 1
fi

client_args=()
if [[ -n "$MYSQL_DEFAULTS_FILE" ]]; then
  if [[ ! -f "$MYSQL_DEFAULTS_FILE" ]]; then
    echo "ERROR: MYSQL_DEFAULTS_FILE does not exist: $MYSQL_DEFAULTS_FILE" >&2
    exit 1
  fi
  client_args=(--defaults-extra-file="$MYSQL_DEFAULTS_FILE")
fi

dump_args=(
  --single-transaction
  --triggers
  --hex-blob
  --add-drop-database
  --add-drop-table
)

echo "Listing databases"
while IFS= read -r db; do
  case "$db" in
    information_schema|performance_schema|sys)
      continue
      ;;
  esac

  dump_file="$BACKUP_DIR/${db}.sql"
  archive_file="${dump_file}.gz"

  echo "Creating database dump: $db"
  if ! "$DUMP_CMD" "${client_args[@]}" "${dump_args[@]}" --databases "$db" > "$dump_file"; then
    echo "ERROR: database dump failed for $db" >&2
    rm -f "$dump_file"
    continue
  fi

  echo "Compressing dump: $(basename "$archive_file")"
  if ! gzip -9 "$dump_file"; then
    echo "ERROR: compression failed for $db" >&2
    rm -f "$dump_file"
    continue
  fi

  echo "Sending dump: $(basename "$archive_file")"
  if rsync -avz -e "ssh -p $REMOTE_PORT" -- "$archive_file" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_SLOT_PATH/"; then
    rm -f "$archive_file"
    echo "Done: $db"
  else
    echo "ERROR: rsync failed for $db; archive kept at $archive_file" >&2
  fi
done < <("$CLIENT_CMD" "${client_args[@]}" -N -B -e "SHOW DATABASES;")
