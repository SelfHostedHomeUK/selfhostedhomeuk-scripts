#!/bin/bash
#
# Full write-up and context: https://selfhostedhome.co.uk/manual-switch-to-resilient-system-wireguard-script-suite/
# Adapt interface names and SUBNET variable for your own setup before use.
#
# wg-failover-check.sh
#
# Run periodically via cron (root). Checks whether the currently active
# WireGuard interface is actually passing traffic. If not, fails over to
# the other configured interface by piping its name into the EXISTING,
# UNMODIFIED wg-switch.sh - exactly as if you'd typed it at the prompt.
# This script never edits, replaces, or re-implements wg-switch.sh logic.

set -uo pipefail   # deliberately no -e: we want to keep going and log, not abort silently

# ---- CONFIG - adjust these for your setup ----
WG_SWITCH="/home/ubuntu/wg-switch.sh"       # path to your existing script
WG_DIR="/etc/wireguard"
INTERFACES=("wg-albania1" "wg-albania2")
PING_TARGETS=("1.1.1.1" "8.8.8.8")
PING_COUNT=3
PING_TIMEOUT=2
COOLDOWN_SECONDS=300
STATE_FILE="/var/run/wg-failover.state"
LOG_FILE="/var/log/wg-failover.log"
LOCK_FILE="/var/run/wg-failover.lock"
MAINT_FLAG="/var/run/wg-maintenance"   # must match the flag path used in wg-refresh.sh

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
    logger -t wg-failover "$*"
}

if [ "$(id -u)" -ne 0 ]; then
    echo "Must run as root" >&2
    exit 1
fi

# Prevent overlapping runs (a switch can take ~30s if it's retrying handshakes)
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exit 0
fi

# Skip silently during the nightly wg-refresh.sh maintenance window - that
# script brings the interface down on purpose, which would otherwise look
# exactly like a real failure and trigger an unwanted failover.
if [ -f "$MAINT_FLAG" ]; then
    exit 0
fi

CURRENT_IF=$(wg show interfaces 2>/dev/null | head -n1)

if [ -z "$CURRENT_IF" ]; then
    log "WARNING: no WireGuard interface is up at all"
    for IF in "${INTERFACES[@]}"; do
        if systemctl is-enabled "wg-quick@${IF}" &>/dev/null; then
            CURRENT_IF="$IF"
            break
        fi
    done
fi

TARGET_IF=""
for IF in "${INTERFACES[@]}"; do
    if [ "$IF" != "$CURRENT_IF" ]; then
        TARGET_IF="$IF"
    fi
done

if [ -z "$CURRENT_IF" ] || [ -z "$TARGET_IF" ]; then
    log "ERROR: could not determine current/target interface, skipping check"
    exit 1
fi

# ---- Health check: does traffic actually flow via $CURRENT_IF? ----
HEALTHY=0
for TARGET in "${PING_TARGETS[@]}"; do
    if ping -I "$CURRENT_IF" -c "$PING_COUNT" -W "$PING_TIMEOUT" "$TARGET" &>/dev/null; then
        HEALTHY=1
        break
    fi
done

if [ "$HEALTHY" -eq 1 ]; then
    exit 0
fi

log "$CURRENT_IF failed health check (no reply from ${PING_TARGETS[*]})"

# ---- Cooldown: don't thrash if we just tried this recently ----
NOW=$(date +%s)
LAST=0
[ -f "$STATE_FILE" ] && LAST=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
if [ $(( NOW - LAST )) -lt "$COOLDOWN_SECONDS" ]; then
    log "Still within ${COOLDOWN_SECONDS}s cooldown from last failover attempt, skipping"
    exit 0
fi

# ---- Sanity check: does the target interface's endpoint even resolve? ----
# If it doesn't, wg-switch.sh will tear down the current (working-ish)
# interface, fail to bring up the target, and leave you fully disconnected.
# Staying on a degraded interface beats that.
CONF="$WG_DIR/${TARGET_IF}.conf"
if [ ! -f "$CONF" ]; then
    log "ERROR: $CONF missing, cannot fail over to $TARGET_IF"
    exit 1
fi

EP_HOST=$(grep -m1 -E '^\s*Endpoint' "$CONF" | sed -E 's/^\s*Endpoint\s*=\s*//; s/:[0-9]+\s*$//')
if [ -n "$EP_HOST" ] && ! getent hosts "$EP_HOST" &>/dev/null; then
    log "ERROR: $TARGET_IF endpoint ($EP_HOST) does not resolve, refusing to fail over - staying on $CURRENT_IF"
    exit 1
fi

# ---- Do the failover, via the existing script, unmodified ----
log "Failing over: $CURRENT_IF -> $TARGET_IF"
echo "$NOW" > "$STATE_FILE"

if echo "$TARGET_IF" | "$WG_SWITCH" >> "$LOG_FILE" 2>&1; then
    # The wg-switch.sh in use here only runs wg-quick up/down - it never
    # touches systemd enablement, so boot state would otherwise be stuck
    # on whatever was last enabled by hand. Fix it up here instead of
    # editing wg-switch.sh itself.
    systemctl enable "wg-quick@${TARGET_IF}" 2>/dev/null || true
    systemctl disable "wg-quick@${CURRENT_IF}" 2>/dev/null || true
    log "Failover to $TARGET_IF completed (boot enablement updated: ${TARGET_IF} enabled, ${CURRENT_IF} disabled)"
else
    log "ERROR: wg-switch.sh exited non-zero switching to $TARGET_IF - check $LOG_FILE"
fi
