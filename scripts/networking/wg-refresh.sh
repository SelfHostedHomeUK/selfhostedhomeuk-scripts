#!/bin/bash
#
# Full write-up and context: https://selfhostedhome.co.uk/manual-switch-to-resilient-system-wireguard-script-suite/
# Adapt interface names and SUBNET variable for your own setup before use.
#
MAINT_FLAG="/var/run/wg-maintenance"

# Find whichever albania interface is up
ACTIVE=$(wg show interfaces | tr ' ' '\n' | grep 'wg-albania')

if [ -z "$ACTIVE" ]; then
    echo "$(date): No Albania interface found, exiting" >> /var/log/wg-refresh.log
    exit 1
fi

# Always clear the flag on exit, even if this script errors out or is
# killed partway through - otherwise the failover check would stay
# paused forever.
trap 'rm -f "$MAINT_FLAG"' EXIT

echo "$(date): Cycling $ACTIVE" >> /var/log/wg-refresh.log
touch "$MAINT_FLAG"
wg-quick down $ACTIVE
sleep 90
wg-quick up $ACTIVE
echo "$(date): $ACTIVE back up" >> /var/log/wg-refresh.log
