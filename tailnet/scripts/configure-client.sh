#!/usr/bin/env bash
# configure-client.sh
#
# Configures a Tailscale client to route all internet-bound traffic through
# the VPS exit node on an always-on basis.
#
# Run this on the desktop and laptop after:
#   - The device is registered with Headscale (scripts/install-tailscale-client.sh).
#   - The VPS exit node routes have been approved in Headscale
#     (scripts/configure-exit-node.sh + manual route approval).
#
# Usage:
#   sudo bash scripts/configure-client.sh <vps-tailscale-ip>
#
# To find the VPS Tailscale IP, run on the VPS:
#   tailscale ip -4
#
# Example:
#   sudo bash scripts/configure-client.sh 100.64.0.1

set -euo pipefail

# --- Configuration -----------------------------------------------------------

# The URL of the self-hosted Headscale control server.
SERVER_URL='https://headscale.perdrizet.org'

# --- Helper functions --------------------------------------------------------

log() {
    echo "[configure-client] $*"
}

die() {
    echo "[configure-client] ERROR: $*" >&2
    exit 1
}

# --- Pre-flight checks -------------------------------------------------------

[[ $EUID -eq 0 ]] \
    || die 'This script must be run as root. Use: sudo bash scripts/configure-client.sh <vps-tailscale-ip>'

[[ $# -ge 1 ]] \
    || die 'A VPS Tailscale IP is required. Usage: sudo bash scripts/configure-client.sh <vps-tailscale-ip>'

command -v tailscale &>/dev/null \
    || die 'Tailscale is not installed. Run scripts/install-tailscale-client.sh first.'

# Confirm that the Tailscale daemon is connected before proceeding.
tailscale status &>/dev/null \
    || die 'Tailscale is not connected. Ensure this device is registered with Headscale before configuring the exit node.'

VPS_IP="$1"

# --- Configure always-on exit node routing -----------------------------------

log "Setting exit node to ${VPS_IP}..."

# --exit-node routes all internet-bound traffic through the specified node.
# --exit-node-allow-lan-access preserves access to local network resources
# (e.g. printers, NAS) even while the exit node is active.
# --reset clears any previously set non-default flags (such as --hostname)
# so that tailscale up does not require them to be restated.
tailscale up \
    --login-server="${SERVER_URL}" \
    --exit-node="${VPS_IP}" \
    --exit-node-allow-lan-access=true \
    --reset

# --- Done --------------------------------------------------------------------

log ''
log "Exit node configured: all internet traffic now routes through ${VPS_IP}."
log ''
log 'Verify by running:'
log '  curl -s https://ifconfig.me'
log 'The returned IP should match the VPS public IP.'
