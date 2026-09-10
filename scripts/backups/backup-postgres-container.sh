#!/bin/bash
# Backs up a Postgres database running in Docker via pg_dump, plus a
# project directory, to a network-mounted destination — same mount
# guard as the sibling script, better fit than stop-and-tar for a
# database that can be dumped live.
#
# Background: https://selfhostedhome.co.uk/the-blog-died-pt3-the-backups-that-worked-but-hadnt/

set -euo pipefail

# ---- Configuration — edit these for your setup ----

NFS_MOUNT="/mnt/backups"
PROJECT_DIR="/home/ubuntu/my-postgres-app"
DEST_DIR="/mnt/backups/MyApp"

# The running Postgres container name, and the db/user to dump
DB_CONTAINER="my-app-db"
DB_NAME="myapp"
DB_USER="myapp"

STATUS="/home/ubuntu/.my-postgres-app-backup-status"
RETENTION_DAYS=14

# ---- End configuration ----

STAMP=$(date +%Y-%m-%d)
TMP_DIR="/tmp/$(basename "$PROJECT_DIR")-bak-$$"

mkdir -p "$DEST_DIR" "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT
trap 'echo "$(date -Is)  ❌  FAIL  script exited unexpectedly" > "$STATUS"' ERR

if ! findmnt "$NFS_MOUNT" >/dev/null; then
  echo "$(date -Is)  ❌  FAIL  network mount $NFS_MOUNT not mounted" > "$STATUS"
  exit 1
fi

docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" \
  | gzip > "$TMP_DIR/$(basename "$PROJECT_DIR")_db-${STAMP}.sql.gz"

tar czf "$TMP_DIR/$(basename "$PROJECT_DIR")-${STAMP}.tar.gz" \
  -C "$(dirname "$PROJECT_DIR")" "$(basename "$PROJECT_DIR")"

cp -a "$TMP_DIR"/* "$DEST_DIR/"
find "$DEST_DIR" -maxdepth 1 -type f -name "$(basename "$PROJECT_DIR")*" -mtime "+${RETENTION_DAYS}" -delete

echo "$(date -Is)  ✅  OK  $STAMP  dest=$DEST_DIR" > "$STATUS"
