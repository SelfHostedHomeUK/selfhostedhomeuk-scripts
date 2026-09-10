#!/bin/bash
# Backs up a Docker Compose stack's named volumes and project directory
# to a network-mounted destination, with a guard against the destination
# not actually being mounted.
#
# Background: https://selfhostedhome.co.uk/the-blog-died-pt3-the-backups-that-worked-but-hadnt/

set -euo pipefail

# ---- Configuration — edit these for your setup ----

# A path inside the network mount, used purely to check the mount is live
NFS_MOUNT="/mnt/backups"

# Directory holding the compose project (docker-compose.yml lives here)
PROJECT_DIR="/home/ubuntu/my-app"

# Where backups actually land — usually somewhere under NFS_MOUNT
DEST_DIR="/mnt/backups/MyApp"

# Named Docker volumes to back up — run `docker volume ls` to find yours
VOLUMES=(
    "my-app_content"
    "my-app_config"
)

# The compose service to stop briefly while its volume is archived.
# Leave as "" to skip this — useful if nothing needs a clean stop.
STOP_SERVICE="app"

# Status file, meant to be read by whatever prints your SSH banner
STATUS="/home/ubuntu/.my-app-backup-status"

# How many days of backups to keep
RETENTION_DAYS=14

# ---- End configuration ----

STAMP=$(date +%Y-%m-%d)
COMPOSE="docker compose -f $PROJECT_DIR/docker-compose.yml --project-directory $PROJECT_DIR"
TMP_DIR="/tmp/$(basename "$PROJECT_DIR")-bak-$$"

mkdir -p "$DEST_DIR" "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT
trap 'echo "$(date -Is)  ❌  FAIL  script exited unexpectedly" > "$STATUS"' ERR

if ! findmnt "$NFS_MOUNT" >/dev/null; then
  echo "$(date -Is)  ❌  FAIL  network mount $NFS_MOUNT not mounted" > "$STATUS"
  exit 1
fi

if [ -n "$STOP_SERVICE" ]; then
  $COMPOSE stop "$STOP_SERVICE"
fi

for VOL in "${VOLUMES[@]}"; do
  docker run --rm \
    -v "$VOL:/v:ro" \
    -v "$TMP_DIR:/b" \
    alpine tar czf "/b/${VOL}-${STAMP}.tar.gz" -C /v .
done

tar czf "$TMP_DIR/$(basename "$PROJECT_DIR")-${STAMP}.tar.gz" \
  -C "$(dirname "$PROJECT_DIR")" "$(basename "$PROJECT_DIR")"

if [ -n "$STOP_SERVICE" ]; then
  $COMPOSE start "$STOP_SERVICE"
fi

cp -a "$TMP_DIR"/*.tar.gz "$DEST_DIR/"
find "$DEST_DIR" -maxdepth 1 -type f -name "$(basename "$PROJECT_DIR")*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete

echo "$(date -Is)  ✅  OK  $STAMP  dest=$DEST_DIR" > "$STATUS"
