#!/usr/bin/env bash
# setup-ssh.sh
#
# Generates an SSH key pair on this device (if one does not already exist) and
# distributes the public key to one or more peer devices over the tailnet.
#
# Run this on each Linux device (desktop, laptop, VPS) after all devices have
# joined the tailnet and Tailscale IPs are available.
#
# This script:
#   1. Creates the ~/.ssh directory with correct permissions if absent.
#   2. Generates an ed25519 key pair at ~/.ssh/id_ed25519 if one does not
#      exist. Uses an empty passphrase for unattended SSH access between
#      personal devices.
#   3. Copies the public key to each target device using ssh-copy-id, using
#      the Tailscale IP to ensure the connection goes over the tailnet.
#
# Usage:
#   bash scripts/setup-ssh.sh <tailscale-ip-1> [tailscale-ip-2 ...]
#
# Examples:
#   # From the desktop, copy keys to the laptop and VPS:
#   bash scripts/setup-ssh.sh 100.64.0.2 100.64.0.3
#
#   # From the VPS, copy keys to the desktop and laptop:
#   bash scripts/setup-ssh.sh 100.64.0.1 100.64.0.2
#
# To find each device's Tailscale IP, run on any device:
#   tailscale status
#
# Note: ssh-copy-id connects to each target over SSH. The target must already
# be running an SSH daemon (sshd) and accessible over the tailnet.
# On first connection, you will be prompted for the target user's password.
# Subsequent connections will use the distributed key and be passwordless.

set -euo pipefail

# --- Configuration -----------------------------------------------------------

# The username used on all devices in this tailnet.
USERNAME='siderealyear'

# The SSH key type and file path.
KEY_TYPE='ed25519'
KEY_FILE="${HOME}/.ssh/id_${KEY_TYPE}"

# --- Helper functions --------------------------------------------------------

log() {
    echo "[setup-ssh] $*"
}

die() {
    echo "[setup-ssh] ERROR: $*" >&2
    exit 1
}

# --- Pre-flight checks -------------------------------------------------------

[[ $# -ge 1 ]] \
    || die 'At least one target Tailscale IP is required. Usage: bash scripts/setup-ssh.sh <ip1> [ip2 ...]'

command -v ssh-keygen  &>/dev/null || die 'ssh-keygen not found. Install openssh-client.'
command -v ssh-copy-id &>/dev/null || die 'ssh-copy-id not found. Install openssh-client.'

# --- Prepare the .ssh directory ----------------------------------------------

# Create with strict permissions; SSH will refuse to use keys in world-readable
# directories.
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

# --- Generate an SSH key pair if one does not already exist ------------------

if [[ -f "${KEY_FILE}" ]]; then
    log "Key already exists at ${KEY_FILE}, skipping generation."

else
    log "Generating a new ${KEY_TYPE} SSH key pair..."

    # An empty passphrase (-N "") allows passwordless SSH between personal
    # devices without requiring an ssh-agent.
    ssh-keygen \
        -t "${KEY_TYPE}" \
        -f "${KEY_FILE}" \
        -N "" \
        -C "${USERNAME}@$(hostname)"

    log "Key pair generated: ${KEY_FILE} and ${KEY_FILE}.pub"
fi

# --- Distribute the public key to each target device ------------------------

for TARGET_IP in "$@"; do
    log "Copying public key to ${USERNAME}@${TARGET_IP}..."

    # StrictHostKeyChecking=accept-new automatically accepts the host key on
    # the first connection and records it in ~/.ssh/known_hosts, avoiding an
    # interactive prompt. Subsequent connections verify the recorded key.
    ssh-copy-id \
        -i "${KEY_FILE}.pub" \
        -o 'StrictHostKeyChecking=accept-new' \
        "${USERNAME}@${TARGET_IP}"

    log "Key copied to ${TARGET_IP}."
done

# --- Done --------------------------------------------------------------------

log ''
log 'SSH key distribution complete.'
log ''
log 'Test each connection with:'

for TARGET_IP in "$@"; do
    log "  ssh ${USERNAME}@${TARGET_IP}"
done

log ''
log 'For named access, MagicDNS hostnames can also be used (once propagated):'
log "  ssh ${USERNAME}@<hostname>.perdrizet.org"
