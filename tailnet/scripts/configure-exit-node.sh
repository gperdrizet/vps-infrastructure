#!/usr/bin/env bash
# configure-exit-node.sh
#
# Configures the VPS as a Tailscale exit node so that all client devices can
# route their internet-bound traffic through it.
#
# Run this on the VPS after:
#   - Headscale is installed and running (scripts/install-headscale.sh).
#   - The VPS has been registered as a Tailscale node (scripts/install-tailscale-client.sh).
#
# This script:
#   1. Enables IPv4 and IPv6 packet forwarding via sysctl. This is a kernel
#      requirement for any machine acting as a traffic router.
#   2. Re-runs tailscale up with --advertise-exit-node to tell the control
#      server that this node is willing to serve as a default-route exit node.
#   3. Prints the commands needed to approve the advertised routes in Headscale.
#      Route approval is a manual step -- see docs/manual-steps.md.
#
# Usage:
#   sudo bash scripts/configure-exit-node.sh

set -euo pipefail

# --- Configuration -----------------------------------------------------------

# The URL of the self-hosted Headscale control server.
SERVER_URL='https://headscale.perdrizet.org'

# Path for the persistent sysctl configuration file.
SYSCTL_CONF='/etc/sysctl.d/99-tailscale.conf'

# --- Helper functions --------------------------------------------------------

log() {
    echo "[configure-exit-node] $*"
}

die() {
    echo "[configure-exit-node] ERROR: $*" >&2
    exit 1
}

# --- Pre-flight checks -------------------------------------------------------

[[ $EUID -eq 0 ]] \
    || die 'This script must be run as root. Use: sudo bash scripts/configure-exit-node.sh'

command -v tailscale &>/dev/null \
    || die 'Tailscale is not installed. Run scripts/install-tailscale-client.sh first.'

command -v headscale &>/dev/null \
    || die 'headscale CLI not found. This script must be run on the VPS where Headscale is installed.'

# Confirm that the Tailscale daemon is connected before proceeding.
tailscale status &>/dev/null \
    || die 'Tailscale is not connected. Register this device first and ensure it is active.'

# --- Enable IP forwarding ----------------------------------------------------

log 'Enabling IPv4 and IPv6 packet forwarding...'

# Write forwarding settings to a drop-in sysctl file so they survive reboots.
# The quoted heredoc (<<'EOF') prevents any shell expansion inside the block.
cat > "${SYSCTL_CONF}" <<'EOF'
# Enable packet forwarding required for Tailscale exit node operation.
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

# Apply the settings immediately without requiring a reboot.
sysctl -p "${SYSCTL_CONF}"

log "IP forwarding enabled and persisted to ${SYSCTL_CONF}."

# --- Advertise as exit node --------------------------------------------------

log 'Advertising this node as a Tailscale exit node...'

# The --advertise-exit-node flag tells Headscale that this node is offering
# to handle 0.0.0.0/0 and ::/0 routes for other devices. The routes will
# appear as pending in Headscale until manually approved.
tailscale up \
    --login-server="${SERVER_URL}" \
    --advertise-exit-node

log 'Exit node advertisement sent to Headscale.'

# --- Print route approval instructions ---------------------------------------

log ''
log 'The exit node routes are now advertised but must be approved in Headscale.'
log 'Run the following commands on this VPS to approve them:'
log ''
log '  sudo headscale nodes list-routes'
log ''
log '  # Approve both exit node routes in a single command (replace 1 with node ID if different):'
log '  sudo headscale nodes approve-routes --identifier 1 --routes "0.0.0.0/0,::/0"'
log ''
log 'After approving the routes, run scripts/configure-client.sh on the desktop'
log 'and laptop to activate always-on exit node routing on those devices.'
log 'See docs/manual-steps.md for the full route approval workflow.'
