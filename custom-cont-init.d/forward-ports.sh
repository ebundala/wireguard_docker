#!/bin/bash

# Exit immediately if any command fails
set -e

# PEER_IP:       The WireGuard VPN IP of the local dev machine (first peer = 10.13.13.2)
# FORWARD_PORTS: Comma-separated list of PUBLIC_PORT:DEV_PORT mappings
#                e.g.  80:80,443:443
PEER_IP="${PEER_IP:-10.13.13.2}"
FORWARD_PORTS="${FORWARD_PORTS:-80:80,443:443}"

echo "=========================================================="
echo "Configuring OCI -> Local WireGuard Client Port Forwarding"
echo "Target Peer IP: ${PEER_IP}"
echo "Port Mappings:  ${FORWARD_PORTS}"
echo "=========================================================="

# Iterate over each PUBLIC_PORT:DEV_PORT pair
IFS=',' read -ra MAPPINGS <<< "${FORWARD_PORTS}"
for MAPPING in "${MAPPINGS[@]}"; do
  
    PUBLIC_PORT="${MAPPING%%:*}"
    DEV_PORT="${MAPPING##*:}"

    echo "----------------------------------------------------------"
    echo "  Applying rule: 0.0.0.0:${PUBLIC_PORT} -> ${PEER_IP}:${DEV_PORT}"

    # Flush any pre-existing rules for this port to prevent duplicates on restart
    iptables -t nat -D PREROUTING -p tcp --dport "${PUBLIC_PORT}" -j DNAT \
        --to-destination "${PEER_IP}:${DEV_PORT}" 2>/dev/null || true
    iptables -t nat -D POSTROUTING -d "${PEER_IP}" -p tcp --dport "${DEV_PORT}" \
        -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -p tcp -d "${PEER_IP}" --dport "${DEV_PORT}" \
        -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

    # DNAT: rewrite the destination of incoming packets to the VPN peer
    iptables -t nat -A PREROUTING -p tcp --dport "${PUBLIC_PORT}" -j DNAT \
        --to-destination "${PEER_IP}:${DEV_PORT}"

    # MASQUERADE: rewrite the source so the peer sends replies back through us
    iptables -t nat -A POSTROUTING -d "${PEER_IP}" -p tcp --dport "${DEV_PORT}" \
        -j MASQUERADE

    # Allow these forwarded packets through the FORWARD chain
    iptables -A FORWARD -p tcp -d "${PEER_IP}" --dport "${DEV_PORT}" \
        -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

    echo "  Rule applied successfully."
done

echo "=========================================================="
echo "All port forwarding rules applied!"
echo "=========================================================="
