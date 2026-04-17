#!/bin/bash
# Remove unused UFW rules for ports that have no services listening
# Ports: 3478 (Tailscale STUN), 41641 (Tailscale WireGuard), 9472 (llama.cpp)
# Delete in reverse order to avoid rule number shifts

set -e

echo "Removing unused UFW rules..."
echo "Rule 21: 41641/udp (v6) - Tailscale WireGuard"
ufw --force delete 21

echo "Rule 20: 3478/udp (v6) - Tailscale STUN"
ufw --force delete 20

echo "Rule 19: 9472/tcp (v6) - llama.cpp GPT server"
ufw --force delete 19

echo "Rule 9: 41641/udp - Tailscale WireGuard"
ufw --force delete 9

echo "Rule 8: 3478/udp - Tailscale STUN"
ufw --force delete 8

echo "Rule 7: 9472/tcp - llama.cpp GPT server"
ufw --force delete 7

echo ""
echo "Cleanup complete! Current rules:"
ufw status numbered
