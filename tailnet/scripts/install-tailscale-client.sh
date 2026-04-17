#!/usr/bin/env bash
# install-tailscale-client.sh
#
# Installs Tailscale on a Linux device and connects it to the self-hosted
# Headscale control server at headscale.perdrizet.org.
#
# This script:
#   1. Installs the official Tailscale package for the current distribution.
#   2. Brings up the Tailscale daemon and points it at the Headscale server.
#
# Run this on each Linux device: the desktop, the laptop, and the VPS (as a
# Tailscale client, alongside the Headscale server process).
#
# Usage (non-interactive, with a pre-auth key):
#   sudo bash scripts/install-tailscale-client.sh --auth-key <key>
#
# Usage (interactive, displays a registration URL):
#   sudo bash scripts/install-tailscale-client.sh
#
# To generate a pre-auth key before running this script, on the VPS run:
#   sudo headscale users list                           # find the numeric user ID
#   sudo headscale preauthkeys create --user <id> --expiration 24h --reusable
#
# If not using a pre-auth key, Tailscale will print a URL like:
#   https://headscale.perdrizet.org/register/nodekey:XXXX...
# Approve the node on the VPS with:
#   sudo headscale nodes register --user <id> --key nodekey:XXXX...
#
# See docs/manual-steps.md for the full node registration workflow.

set -euo pipefail

# --- Configuration -----------------------------------------------------------

# The URL of the self-hosted Headscale control server.
SERVER_URL='https://headscale.perdrizet.org'

# --- Argument parsing --------------------------------------------------------

AUTH_KEY=''

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auth-key)
            [[ $# -ge 2 ]] || die '--auth-key requires a value.'
            AUTH_KEY="$2"
            shift 2
            ;;
        *)
            echo "[install-tailscale-client] ERROR: Unknown argument: $1" >&2
            echo 'Usage: sudo bash scripts/install-tailscale-client.sh [--auth-key <key>]' >&2
            exit 1
            ;;
    esac
done

# --- Helper functions --------------------------------------------------------

log() {
    echo "[install-tailscale-client] $*"
}

die() {
    echo "[install-tailscale-client] ERROR: $*" >&2
    exit 1
}

# --- Pre-flight checks -------------------------------------------------------

[[ $EUID -eq 0 ]] \
    || die 'This script must be run as root. Use: sudo bash scripts/install-tailscale-client.sh'

command -v curl &>/dev/null \
    || die 'curl is required but not installed. Run: apt-get install -y curl'

# --- Install Tailscale -------------------------------------------------------

log 'Installing Tailscale using the official install script...'

# The official script detects the distribution and configures the correct
# package repository, then installs the tailscale and tailscaled packages.
curl -fsSL https://tailscale.com/install.sh | sh

log 'Tailscale installed.'

# Wait for the tailscaled daemon to become ready. On some distributions the
# daemon is started by the install script but needs a moment to initialize
# its backend before tailscale up can connect to it.
log 'Waiting for tailscaled to become ready...'
for i in $(seq 1 15); do
    tailscale status &>/dev/null && break
    sleep 1
done
# Give it one extra second after the socket is up to avoid a 503 race.
sleep 1

# --- Connect to the Headscale control server ---------------------------------

if [[ -n "$AUTH_KEY" ]]; then
    # A pre-auth key was provided; connect non-interactively.
    log 'Connecting to Headscale using the provided pre-auth key...'

    tailscale up \
        --login-server="${SERVER_URL}" \
        --auth-key="${AUTH_KEY}" \
        --force-reauth

    log 'Connected successfully.'
    log "Run 'tailscale status' to confirm this device appears in the tailnet."

else
    # No pre-auth key; Tailscale will print a registration URL that must be
    # approved on the VPS using the headscale CLI.
    log 'Connecting to Headscale (interactive registration)...'
    log 'Tailscale will print a URL. To approve this device, on the VPS run:'
    log '  sudo headscale users list                        # get the numeric user ID'
    log '  sudo headscale nodes register --user <id> --key <nodekey from URL>'

    tailscale up --login-server="${SERVER_URL}"
fi

# --- Done --------------------------------------------------------------------

log ''
log 'Tailscale client setup complete.'
log ''
log 'Next steps:'
log '  1. Verify registration on the VPS: headscale nodes list'
log '  2. After all devices are registered, run: sudo bash scripts/configure-exit-node.sh (on the VPS)'
log '  3. Then run: sudo bash scripts/configure-client.sh <vps-tailscale-ip> (on this device)'
log '  See docs/manual-steps.md for the full workflow.'
