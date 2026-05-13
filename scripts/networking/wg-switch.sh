#!/bin/bash
set -euo pipefail

SUBNET="192.168.1.192/27"
WG_DIR="/etc/wireguard"

echo "========================================"
echo "  Roku VPN Gateway Switcher"
echo "========================================"
echo ""

# Auto-detect LAN interface
LAN_IF=$(ip route | awk '/default/ {print $5}')

if [ -z "$LAN_IF" ]; then
    echo "ERROR: Could not detect LAN interface"
    exit 1
fi

echo "Detected LAN interface: $LAN_IF"
echo ""

# Detect currently active WG interface (if any)
OLD_IF=$(wg show interfaces 2>/dev/null || true)

read -p "New interface (wg-albania1 / wg-albania2): " NEW_IF

echo ""
echo ">> Validating config..."

if [ ! -f "$WG_DIR/${NEW_IF}.conf" ]; then
    echo "ERROR: Missing $WG_DIR/${NEW_IF}.conf"
    exit 1
fi

# ----------------------------
# STOP OLD INTERFACE
# ----------------------------
if [ -n "$OLD_IF" ]; then
    echo ""
    echo ">> Stopping active interface: $OLD_IF"

    wg-quick down "$OLD_IF" 2>/dev/null || true

    echo ">> Removing old firewall rules..."

    iptables -D FORWARD -o "$OLD_IF" -s "$SUBNET" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$OLD_IF" -o "$LAN_IF" -d "$SUBNET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -o "$OLD_IF" -s "$SUBNET" -j MASQUERADE 2>/dev/null || true
fi

# ----------------------------
# START NEW INTERFACE
# ----------------------------
echo ""
echo ">> Starting new interface: $NEW_IF"

wg-quick up "$NEW_IF"

sleep 3

# ----------------------------
# VERIFY HANDSHAKE
# ----------------------------
echo ""
echo ">> Checking WireGuard handshake..."

for i in {1..10}; do
    if wg show "$NEW_IF" 2>/dev/null | grep -q "latest handshake"; then
        echo ">> Handshake confirmed."
        break
    fi
    echo "   Waiting for handshake... attempt $i/10"
    sleep 3
done

if ! wg show "$NEW_IF" 2>/dev/null | grep -q "latest handshake"; then
    echo "ERROR: No handshake after 30 seconds -- aborting"
    wg-quick down "$NEW_IF" 2>/dev/null || true
    exit 1
fi

# ----------------------------
# APPLY CLEAN IPTABLES (NO DUPLICATES)
# ----------------------------
echo ""
echo ">> Applying firewall rules..."

# Forward LAN to VPN
iptables -C FORWARD -o "$NEW_IF" -s "$SUBNET" -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -o "$NEW_IF" -s "$SUBNET" -j ACCEPT

# Forward VPN to LAN (return traffic)
iptables -C FORWARD -i "$NEW_IF" -o "$LAN_IF" -d "$SUBNET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "$NEW_IF" -o "$LAN_IF" -d "$SUBNET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# NAT (exit via VPN)
iptables -t nat -C POSTROUTING -o "$NEW_IF" -s "$SUBNET" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o "$NEW_IF" -s "$SUBNET" -j MASQUERADE

# ----------------------------
# FINAL STATUS CHECK
# ----------------------------
echo ""
echo "========================================"
echo " SWITCH COMPLETE"
echo "========================================"

echo ""
echo "Active WireGuard:"
wg show "$NEW_IF" || true

echo ""
echo "Default route:"
ip route | grep default || true

echo ""
echo "FORWARD rules:"
iptables -L FORWARD -n -v --line-numbers

echo ""
echo "NAT rules:"
iptables -t nat -L POSTROUTING -n -v --line-numbers

echo ""
echo "LAN interface used: $LAN_IF"

echo ""
echo "========================================"
echo " SYSTEM READY (ROKU VPN ACTIVE)"
echo "========================================"
