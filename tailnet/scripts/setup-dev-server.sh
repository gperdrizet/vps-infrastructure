#!/usr/bin/env bash
# setup-dev-server.sh
#
# Sets up a remote development environment on pyrite (or any tailnet node):
#   - OpenVSCode Server (VS Code in the browser, full Microsoft marketplace)
#   - JupyterLab (notebook interface in the browser)
#   - autossh reverse tunnel to the VPS so both are reachable from the internet
#
# Both services listen on localhost only. The VPS nginx proxies:
#   https://code.perdrizet.org    → 127.0.0.1:8080 (openvscode-server)
#   https://jupyter.perdrizet.org → 127.0.0.1:47302 (jupyterlab)
#
# Usage:
#   sudo bash setup-dev-server.sh [--user <username>] [--vps <host>] [--vps-user <username>]
#
# Defaults:
#   --user      siderealyear    (local user to run the dev services as)
#   --vps       74.208.107.78   (VPS host for the autossh tunnel)
#   --vps-user  siderealyear    (VPS username for the SSH tunnel connection)
#
# After running this script:
#   1. Copy the printed public key to ~/.ssh/authorized_keys on the VPS:
#        restrict,port-forwarding,no-pty,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA... pyrite-tunnel
#   2. Set the VS Code web password on the VPS:
#        sudo apt install apache2-utils
#        sudo htpasswd -c /etc/nginx/.htpasswd-code <username>
#   3. Set the JupyterLab password on pyrite (run as the dev user):
#        /opt/jupyterlab-venv/bin/jupyter server password
#   4. Start the tunnel: sudo systemctl start dev-tunnel
#   5. Verify both services are reachable from the VPS:
#        curl -s http://127.0.0.1:8080 | head -5
#        curl -s http://127.0.0.1:47302 | head -5

set -euo pipefail

# --- Configuration -----------------------------------------------------------

DEV_USER='siderealyear'
VPS_HOST='74.208.107.78'
VPS_PORT='44441'
VPS_USER='siderealyear'

OPENVSCODE_INSTALL_DIR='/opt/openvscode-server'
JUPYTER_VENV_DIR='/opt/jupyterlab-venv'
TUNNEL_KEY='/etc/dev-tunnel/id_ed25519'
VSCODE_CLI_INSTALL_DIR='/opt/vscode-cli'
VSCODE_TUNNEL_NAME='pyrite'

# --- Argument parsing --------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            [[ $# -ge 2 ]] || { echo "ERROR: --user requires a value." >&2; exit 1; }
            DEV_USER="$2"; shift 2 ;;
        --vps)
            [[ $# -ge 2 ]] || { echo "ERROR: --vps requires a value." >&2; exit 1; }
            VPS_HOST="$2"; shift 2 ;;
        --vps-user)
            [[ $# -ge 2 ]] || { echo "ERROR: --vps-user requires a value." >&2; exit 1; }
            VPS_USER="$2"; shift 2 ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "Usage: sudo bash setup-dev-server.sh [--user <username>] [--vps <host>] [--vps-user <username>]" >&2
            exit 1 ;;
    esac
done

# --- Helper functions --------------------------------------------------------

log()  { echo "[setup-dev-server] $*"; }
die()  { echo "[setup-dev-server] ERROR: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

[[ $EUID -eq 0 ]] || die "This script must be run as root (sudo)."
id "$DEV_USER" &>/dev/null || die "User '$DEV_USER' does not exist."

DEV_USER_HOME=$(getent passwd "$DEV_USER" | cut -d: -f6)

# --- Detect architecture -----------------------------------------------------

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  OPENVSCODE_ARCH='x64'   ; VSCODE_CLI_ARCH='cli-alpine-x64'   ;;
    aarch64) OPENVSCODE_ARCH='arm64' ; VSCODE_CLI_ARCH='cli-alpine-arm64' ;;
    armv7l)  OPENVSCODE_ARCH='armhf' ; VSCODE_CLI_ARCH='cli-alpine-armhf' ;;
    *) die "Unsupported architecture: $ARCH" ;;
esac

log "Detected architecture: $ARCH → openvscode-server asset: linux-$OPENVSCODE_ARCH"
log "VS Code CLI asset: $VSCODE_CLI_ARCH"

# --- Install dependencies ----------------------------------------------------

step "Installing system dependencies"
apt-get update -qq
apt-get install -y -qq autossh curl wget python3 python3-venv python3-pip git

# --- Install OpenVSCode Server -----------------------------------------------

step "Installing OpenVSCode Server"

log "Fetching latest release tag from GitHub..."
LATEST_TAG=$(curl -fsSL https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)

[[ -n "$LATEST_TAG" ]] || die "Failed to fetch latest openvscode-server release tag."
log "Latest release: $LATEST_TAG"

OPENVSCODE_TARBALL="${LATEST_TAG}-linux-${OPENVSCODE_ARCH}.tar.gz"
OPENVSCODE_URL="https://github.com/gitpod-io/openvscode-server/releases/download/${LATEST_TAG}/${OPENVSCODE_TARBALL}"

if [[ -d "$OPENVSCODE_INSTALL_DIR" ]]; then
    INSTALLED_VERSION=$(cat "$OPENVSCODE_INSTALL_DIR/version" 2>/dev/null || echo "unknown")
    if [[ "$INSTALLED_VERSION" == "$LATEST_TAG" ]]; then
        log "OpenVSCode Server $LATEST_TAG already installed, skipping download."
    else
        log "Upgrading from $INSTALLED_VERSION to $LATEST_TAG..."
        rm -rf "$OPENVSCODE_INSTALL_DIR"
    fi
fi

if [[ ! -d "$OPENVSCODE_INSTALL_DIR" ]]; then
    log "Downloading $OPENVSCODE_TARBALL..."
    TMP_DIR=$(mktemp -d)
    wget -qO "$TMP_DIR/$OPENVSCODE_TARBALL" "$OPENVSCODE_URL" \
        || die "Download failed: $OPENVSCODE_URL"

    log "Extracting to $OPENVSCODE_INSTALL_DIR..."
    mkdir -p "$OPENVSCODE_INSTALL_DIR"
    tar -xzf "$TMP_DIR/$OPENVSCODE_TARBALL" -C "$OPENVSCODE_INSTALL_DIR" --strip-components=1
    echo "$LATEST_TAG" > "$OPENVSCODE_INSTALL_DIR/version"
    rm -rf "$TMP_DIR"
fi

chown -R "$DEV_USER:$DEV_USER" "$OPENVSCODE_INSTALL_DIR"
log "OpenVSCode Server installed at $OPENVSCODE_INSTALL_DIR"

# --- Install JupyterLab ------------------------------------------------------

step "Installing JupyterLab"

if [[ ! -f "$JUPYTER_VENV_DIR/bin/jupyter" ]]; then
    log "Creating Python venv at $JUPYTER_VENV_DIR..."
    python3 -m venv "$JUPYTER_VENV_DIR"
    "$JUPYTER_VENV_DIR/bin/pip" install --quiet --upgrade pip
    "$JUPYTER_VENV_DIR/bin/pip" install --quiet jupyterlab
else
    log "JupyterLab already installed, upgrading..."
    "$JUPYTER_VENV_DIR/bin/pip" install --quiet --upgrade jupyterlab
fi

chown -R "$DEV_USER:$DEV_USER" "$JUPYTER_VENV_DIR"
log "JupyterLab installed at $JUPYTER_VENV_DIR"

# --- Install VS Code CLI (for vscode.dev tunnel + Copilot) ------------------

step "Installing VS Code CLI"

VSCODE_CLI_URL="https://code.visualstudio.com/sha/download?build=stable&os=${VSCODE_CLI_ARCH}"

if [[ ! -f "$VSCODE_CLI_INSTALL_DIR/code" ]]; then
    log "Downloading VS Code CLI ($VSCODE_CLI_ARCH)..."
    TMP_CLI=$(mktemp -d)
    curl -fsSL "$VSCODE_CLI_URL" -o "$TMP_CLI/vscode-cli.tar.gz" \
        || die "Failed to download VS Code CLI from $VSCODE_CLI_URL"
    mkdir -p "$VSCODE_CLI_INSTALL_DIR"
    tar -xzf "$TMP_CLI/vscode-cli.tar.gz" -C "$VSCODE_CLI_INSTALL_DIR"
    rm -rf "$TMP_CLI"
    chmod 755 "$VSCODE_CLI_INSTALL_DIR/code"
    log "VS Code CLI installed at $VSCODE_CLI_INSTALL_DIR/code"
else
    log "VS Code CLI already present at $VSCODE_CLI_INSTALL_DIR/code, skipping."
fi

chown -R "$DEV_USER:$DEV_USER" "$VSCODE_CLI_INSTALL_DIR"

# --- Generate JupyterLab config ----------------------------------------------

step "Configuring JupyterLab"

JUPYTER_CONFIG_DIR="$DEV_USER_HOME/.jupyter"
JUPYTER_CONFIG_FILE="$JUPYTER_CONFIG_DIR/jupyter_server_config.py"

mkdir -p "$JUPYTER_CONFIG_DIR"
chown "$DEV_USER:$DEV_USER" "$JUPYTER_CONFIG_DIR"

if [[ ! -f "$JUPYTER_CONFIG_FILE" ]]; then
    cat > "$JUPYTER_CONFIG_FILE" <<'EOF'
# JupyterLab server configuration
# Generated by setup-dev-server.sh

c.ServerApp.ip = '127.0.0.1'
c.ServerApp.port = 47302
c.ServerApp.open_browser = False
c.ServerApp.allow_remote_access = False
c.ServerApp.allow_origin = '*'
c.ServerApp.local_hostnames = ['localhost', '127.0.0.1', '::1', 'jupyter.perdrizet.org']

# Password is set separately with: jupyter server password
# The hashed password will be stored in jupyter_server_config.json
EOF
    chown "$DEV_USER:$DEV_USER" "$JUPYTER_CONFIG_FILE"
    log "JupyterLab config written to $JUPYTER_CONFIG_FILE"
else
    log "JupyterLab config already exists, skipping."
fi

# --- Generate SSH tunnel key -------------------------------------------------

step "Generating SSH tunnel key"

mkdir -p "$(dirname "$TUNNEL_KEY")"

if [[ ! -f "$TUNNEL_KEY" ]]; then
    ssh-keygen -t ed25519 -f "$TUNNEL_KEY" -N "" -C "pyrite-tunnel"
    chmod 600 "$TUNNEL_KEY"
    chmod 644 "${TUNNEL_KEY}.pub"
    log "Tunnel key generated at $TUNNEL_KEY"
else
    log "Tunnel key already exists at $TUNNEL_KEY, skipping generation."
fi

# --- Create systemd service: openvscode-server --------------------------------

step "Creating systemd service: openvscode-server"

cat > /etc/systemd/system/openvscode-server.service <<EOF
[Unit]
Description=OpenVSCode Server
After=network.target
Documentation=https://github.com/gitpod-io/openvscode-server

[Service]
Type=simple
User=$DEV_USER
Group=$DEV_USER
WorkingDirectory=$DEV_USER_HOME

ExecStart=$OPENVSCODE_INSTALL_DIR/bin/openvscode-server \\
    --host 127.0.0.1 \\
    --port 47301 \\
    --without-connection-token \\
    --server-data-dir $DEV_USER_HOME/.openvscode-server \\
    --proxy-uri https://code.perdrizet.org

Restart=on-failure
RestartSec=10

# Prevent service from accessing other users' files
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

log "openvscode-server.service written"

# --- Create systemd service: jupyterlab ---------------------------------------

step "Creating systemd service: jupyterlab"

cat > /etc/systemd/system/jupyterlab.service <<EOF
[Unit]
Description=JupyterLab Server
After=network.target
Documentation=https://jupyter.org

[Service]
Type=simple
User=$DEV_USER
Group=$DEV_USER
WorkingDirectory=$DEV_USER_HOME

ExecStart=$JUPYTER_VENV_DIR/bin/jupyter lab \\
    --no-browser \\
    --ip=127.0.0.1 \\
    --port=47302

Restart=on-failure
RestartSec=10

PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

log "jupyterlab.service written"

# --- Create systemd service: dev-tunnel (autossh) ----------------------------

step "Creating systemd service: dev-tunnel"

cat > /etc/systemd/system/dev-tunnel.service <<EOF
[Unit]
Description=autossh reverse tunnel to VPS for remote dev services
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
User=root

ExecStart=/usr/bin/autossh -M 0 -N \\
    -i $TUNNEL_KEY \\
    -p ${VPS_PORT} \\
    -o "ServerAliveInterval=30" \\
    -o "ServerAliveCountMax=3" \\
    -o "ExitOnForwardFailure=yes" \\
    -o "StrictHostKeyChecking=accept-new" \\
    -o "BatchMode=yes" \\
    -R 127.0.0.1:47301:127.0.0.1:47301 \
    -R 127.0.0.1:47302:127.0.0.1:47302 \
    ${VPS_USER}@${VPS_HOST}

Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

log "dev-tunnel.service written"

# --- Create systemd service: vscode-tunnel ------------------------------------

step "Creating systemd service: vscode-tunnel"

cat > /etc/systemd/system/vscode-tunnel.service <<EOF
[Unit]
Description=VS Code Tunnel (Microsoft relay for Copilot access)
After=network-online.target
Wants=network-online.target
Documentation=https://code.visualstudio.com/docs/remote/tunnels

[Service]
Type=simple
User=$DEV_USER
Group=$DEV_USER
WorkingDirectory=$DEV_USER_HOME

# Run 'sudo -u $DEV_USER $VSCODE_CLI_INSTALL_DIR/code tunnel user login --provider github'
# once before starting this service to authenticate with GitHub.
ExecStart=$VSCODE_CLI_INSTALL_DIR/code tunnel \\
    --name $VSCODE_TUNNEL_NAME \\
    --accept-server-license-terms

Restart=on-failure
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

log "vscode-tunnel.service written"

# --- Enable and start services -----------------------------------------------

step "Enabling services (not starting yet)"

systemctl daemon-reload
systemctl enable openvscode-server.service
systemctl enable jupyterlab.service
systemctl enable dev-tunnel.service
systemctl enable vscode-tunnel.service

log "Services enabled. They will start on next boot, or manually with:"
log "  sudo systemctl start openvscode-server jupyterlab"
log "  (start dev-tunnel AFTER adding the public key to the VPS)"
log "  (start vscode-tunnel AFTER authenticating with GitHub — see step 4 below)"

# --- Print next steps --------------------------------------------------------

TUNNEL_PUBKEY=$(cat "${TUNNEL_KEY}.pub")

echo
echo "============================================================"
echo " Setup complete. Manual steps required before starting:"
echo "============================================================"
echo
echo "1. ADD THIS PUBLIC KEY to ~/.ssh/authorized_keys on the VPS ($VPS_USER@$VPS_HOST):"
echo
echo "   restrict,port-forwarding,no-pty,no-X11-forwarding,no-agent-forwarding $TUNNEL_PUBKEY"
echo
echo "2. SET VS CODE PASSWORD on the VPS (one-time):"
echo "   sudo apt install apache2-utils"
echo "   sudo htpasswd -c /etc/nginx/.htpasswd-code <username>"
echo
echo "3. SET JUPYTERLAB PASSWORD on pyrite (run as $DEV_USER):"
echo "   $JUPYTER_VENV_DIR/bin/jupyter server password"
echo
echo "4. START SERVICES on pyrite:"
echo "   sudo systemctl start openvscode-server jupyterlab"
echo "   sudo systemctl start dev-tunnel"
echo
echo "5. VERIFY tunnel on VPS:"
echo "   curl -s http://127.0.0.1:47301 | head -3  # should return HTML"
echo "   curl -s http://127.0.0.1:47302 | head -3   # should return HTML"
echo
echo "4b. AUTHENTICATE VS CODE TUNNEL with GitHub (one-time, interactive):"
echo "    sudo -u $DEV_USER $VSCODE_CLI_INSTALL_DIR/code tunnel user login --provider github"
echo "    → Opens a browser URL — sign in as gperdrizet, authorize the app"
echo "    Then start the tunnel service:"
echo "    sudo systemctl start vscode-tunnel"
echo
echo "Access from the browser:"
echo "   VS Code (open VSX, no Copilot): https://code.perdrizet.org"
echo "   VS Code (MS marketplace, Copilot): https://vscode.dev/tunnel/$VSCODE_TUNNEL_NAME"
echo "   JupyterLab: https://jupyter.perdrizet.org"
echo "============================================================"
