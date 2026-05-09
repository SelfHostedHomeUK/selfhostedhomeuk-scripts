#!/bin/bash
# setup-plex-backup-monitor.sh
# Self Hosted Home UK — github.com/SelfHostedHomeUK
#
# Sets up a nightly Plex Media Server backup via rsync to a destination
# of your choice, and adds a login message to .bashrc showing when the
# last backup ran — with a warning if it has been more than 24 hours.
#
# Usage:
#   chmod +x setup-plex-backup-monitor.sh
#   ./setup-plex-backup-monitor.sh
#
# Requirements:
#   - Plex Media Server installed in the standard location
#   - Backup destination mounted and writable before running
#   - Ubuntu / Debian based system

set -e

echo ""
echo "Plex Backup Monitor Setup"
echo "Self Hosted Home UK — selfhostedhome.co.uk"
echo "────────────────────────────────────────────"
echo ""

# Standard Plex source location
BACKUP_SRC="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/"

# Verify Plex is installed in the standard location
if [ ! -d "$BACKUP_SRC" ]; then
    echo "⚠️  Plex Media Server not found at the standard location:"
    echo "   $BACKUP_SRC"
    echo "   Please verify your Plex installation and try again."
    exit 1
fi

echo "✅  Plex Media Server found at standard location."
echo ""

# Prompt for backup destination
read -p "Enter the full path to your backup destination (e.g. /mnt/backup/Plex): " BACKUP_DEST

if [ -z "$BACKUP_DEST" ]; then
    echo "❌  No backup destination provided. Exiting."
    exit 1
fi

if [ ! -d "$BACKUP_DEST" ]; then
    echo "⚠️  Destination directory does not exist: $BACKUP_DEST"
    read -p "Create it now? (y/n): " CREATE_DIR
    if [ "$CREATE_DIR" = "y" ]; then
        mkdir -p "$BACKUP_DEST"
        echo "✅  Created: $BACKUP_DEST"
    else
        echo "❌  Backup destination not available. Exiting."
        exit 1
    fi
fi

echo ""

# Prompt for timestamp file location
read -p "Enter the full path for the backup timestamp file [default: /home/ubuntu/.last_plex_backup]: " TIMESTAMP_FILE
TIMESTAMP_FILE=${TIMESTAMP_FILE:-/home/ubuntu/.last_plex_backup}

echo ""
echo "Summary:"
echo "  Backup source : $BACKUP_SRC"
echo "  Backup dest   : $BACKUP_DEST"
echo "  Timestamp file: $TIMESTAMP_FILE"
echo "  Cron schedule : Daily at 02:00"
echo ""
read -p "Proceed with this configuration? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# 1. Add cron job (remove any existing plex backup cron first)
CRON_CMD="0 2 * * * sudo rsync -a --delete \"$BACKUP_SRC\" \"$BACKUP_DEST\" && date '+\%Y-\%m-\%d \%H:\%M:\%S' > $TIMESTAMP_FILE"
( crontab -l 2>/dev/null | grep -v "last_plex_backup" | grep -v "Plex Media Server"; echo "$CRON_CMD" ) | crontab -
echo "✅  Cron job added — nightly backup at 02:00"

# 2. Add bashrc login message if not already present
if grep -q "last_plex_backup" ~/.bashrc; then
    echo "ℹ️   Bashrc block already present — skipping"
else
    cat >> ~/.bashrc << BASHRC

# Plex backup monitor — added by setup-plex-backup-monitor.sh
if [ -f $TIMESTAMP_FILE ]; then
    last_backup=\$(cat $TIMESTAMP_FILE)
    last_backup_epoch=\$(date -d "\$last_backup" +%s)
    now_epoch=\$(date +%s)
    diff_hours=\$(( (now_epoch - last_backup_epoch) / 3600 ))
    if [ "\$diff_hours" -gt 24 ]; then
        echo "⚠️  Last Plex backup: \$last_backup (\$diff_hours hours ago)"
    else
        echo "✅  Last Plex backup: \$last_backup"
    fi
else
    echo "⚠️  No Plex backup recorded yet"
fi
BASHRC
    echo "✅  Bashrc block added — will show on next SSH login"
fi

echo ""
echo "────────────────────────────────────────────"
echo "Setup complete. The first backup will run tonight at 02:00."
echo "To test immediately: sudo rsync -a --delete \"$BACKUP_SRC\" \"$BACKUP_DEST\""
echo ""
