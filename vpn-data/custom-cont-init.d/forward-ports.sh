#!/bin/bash

# Exit immediately if any command fails
set -e

# Default to PEER_IP = 10.13.13.2 if not set
PEER_IP="${PEER_IP:-10.13.13.2}"
PUBLIC_PORT="${PUBLIC_PORT:-8080}"
DEV_PORT="${DEV_PORT:-3000}"

echo "=========================================================="
echo "Configuring OCI -> Local Wireguard Client Port Forwarding"
echo "Public Port:      ${PUBLIC_PORT}"
echo "Target Peer IP:   ${PEER_IP}"
echo "Local Dev Port:   ${DEV_PORT}"
echo "=========================================================="

# Flush existing iptables NAT rules for the public port if any exist (prevents duplicates)
iptables -t nat -D PREROUTING -p tcp --dport "${PUBLIC_PORT}" -j DNAT --to-destination "${PEER_IP}:${DEV_PORT}" 2>/dev/null || true
iptables -t nat -D POSTROUTING -d "${PEER_IP}" -p tcp --dport "${DEV_PORT}" -j MASQUERADE 2>/dev/null || true

# Append DNAT (Destination NAT) rule to forward traffic to the VPN peer
iptables -t nat -A PREROUTING -p tcp --dport "${PUBLIC_PORT}" -j DNAT --to-destination "${PEER_IP}:${DEV_PORT}"

# Append MASQUERADE rule so response traffic routes back through the VPN server container
iptables -t nat -A POSTROUTING -d "${PEER_IP}" -p tcp --dport "${DEV_PORT}" -j MASQUERADE

# Allow forwarding for this port specifically in the FORWARD chain
iptables -D FORWARD -p tcp -d "${PEER_IP}" --dport "${DEV_PORT}" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -p tcp -d "${PEER_IP}" --dport "${DEV_PORT}" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

echo "Port forwarding rule successfully applied!"
