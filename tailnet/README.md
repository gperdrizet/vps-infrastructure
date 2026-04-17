# Tailnet setup

Personal tailnet using Headscale as a self-hosted control server, with the VPS
acting as an always-on exit node for all devices. All Linux devices communicate
via standard SSH over Tailscale-assigned IPs.

## Architecture

- Control server: Headscale at headscale.perdrizet.org, hosted on the VPS.
- All four devices join the tailnet and receive IPs in the 100.64.0.0/10 range.
- The VPS advertises itself as a default-route exit node; all internet-bound
  traffic from every device routes through it.
- SSH between Linux devices uses Tailscale IPs (100.x.x.x) or MagicDNS
  hostnames (e.g. gatekeeper.ts.perdrizet.org). MagicDNS is enabled in
  the Headscale config with base_domain set to ts.perdrizet.org.
- DERP fallback uses Tailscale's public relay servers; no self-hosted DERP is
  needed.

### TLS and nginx reverse proxy

Headscale does not terminate TLS directly. Instead, nginx acts as the TLS
termination layer and reverse proxy on the VPS:

- nginx listens on port 80 and 443.
- Port 80 redirects to HTTPS.
- nginx terminates TLS using a Let's Encrypt certificate (managed by certbot)
  for headscale.perdrizet.org.
- All HTTPS traffic to headscale.perdrizet.org is proxied to Headscale, which
  listens on http://127.0.0.1:8090 (no TLS).
- WebSocket upgrades are passed through so Tailscale clients can maintain
  long-lived connections.

The nginx site config lives at /etc/nginx/sites-available/headscale and a copy
is retained in configs/nginx-headscale.conf in this repository.

## Devices

| Device          | Role                                  | System hostname | Tailscale IP |
|-----------------|---------------------------------------|-----------------|---------------|
| Desktop         | Tailscale client                      | pyrite          | 100.64.0.2   |
| Laptop          | Tailscale client                      | laptop          | 100.64.0.3   |
| Phone           | Tailscale client                      | phone           | TBD          |
| VPS (gatekeeper)| Headscale server, Tailscale exit node | gatekeeper      | 100.64.0.1   |

Tailscale IPs are assigned dynamically on first registration. Run
`tailscale status` on any device to view current IPs.

## Setup order

Steps marked as "manual" require action in the terminal, a browser, or a
device UI and cannot be fully scripted. See docs/manual-steps.md for those
steps.

1. Add a DNS A record for headscale.perdrizet.org (manual).
2. Install Headscale on the VPS (also installs nginx reverse proxy and certbot).
3. Generate a pre-auth key on the VPS (manual, optional but recommended).
4. Install Tailscale on each Linux device.
5. Approve each node on the VPS (manual if not using pre-auth keys).
6. Configure the VPS as an exit node.
7. Approve the exit node routes on the VPS (manual).
8. Configure exit node routing on the desktop and laptop.
9. Distribute SSH keys between all Linux devices.
10. Configure the phone (manual).

## Scripts

| Script                              | Run on           | Purpose                                            |
|-------------------------------------|------------------|----------------------------------------------------|
| scripts/install-headscale.sh        | VPS              | Installs and configures Headscale                  |
| scripts/install-tailscale-client.sh | Each Linux device| Installs Tailscale and registers with Headscale    |
| scripts/configure-exit-node.sh      | VPS              | Enables IP forwarding and advertises as exit node  |
| scripts/configure-client.sh         | Desktop, laptop  | Configures always-on exit node routing             |
| scripts/setup-ssh.sh                | Each Linux device| Generates SSH keys and distributes them to peers   |

All scripts must be run as root (or with sudo) unless noted otherwise.

## Verification

After completing setup, run the following checks on each device.

Check that all peers are visible:
```
tailscale status
```

Check that a peer is reachable:
```
ping <tailscale-ip>
```

Check that passwordless SSH login works:
```
ssh siderealyear@<tailscale-ip>
```

Or use a MagicDNS hostname:
```
ssh siderealyear@<device>.ts.perdrizet.org
```

Verify that internet traffic exits via the VPS:
```
curl -s https://ifconfig.me
```
The returned IP should match the VPS public IP (74.208.107.78), confirming
that the exit node is active.

Verify the Headscale control server is reachable:
```
curl -s https://headscale.perdrizet.org/health
```
Should return `{"status":"pass"}`.
