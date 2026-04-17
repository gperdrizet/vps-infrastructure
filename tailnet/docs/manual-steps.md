# Manual setup steps

Some steps in the tailnet setup cannot be fully automated. This document covers
each manual step in the order it appears in the setup sequence from README.md.

## Step 1: Add a DNS A record

Before installing Headscale, add a DNS A record pointing the control server
subdomain to the VPS public IP address. This record must exist and propagate
before certbot can issue a TLS certificate during the install.

In your DNS provider, create:

| Type | Name                       | Value            | TTL   |
|------|----------------------------|------------------|-------|
| A    | headscale.perdrizet.org    | <VPS public IP>  | 300   |

Verify propagation before proceeding:

```
dig headscale.perdrizet.org A +short
```

The command should return the VPS public IP. If it does not, wait for the TTL
to expire and try again.

---

## Step 1a: Verify nginx and certbot after install

After running `scripts/install-headscale.sh`, confirm that nginx is serving
Headscale correctly and that the TLS certificate was issued.

Check that nginx is running and the headscale site is active:
```
sudo nginx -t
sudo systemctl status nginx
sudo ls -la /etc/nginx/sites-enabled/
```

Check that the Let's Encrypt certificate exists:
```
sudo certbot certificates
```

The output should show a certificate for `headscale.perdrizet.org` with a
valid expiry date. Certbot installs a cron job or systemd timer to renew the
certificate automatically.

Confirm the Headscale health endpoint responds over HTTPS:
```
curl -s https://headscale.perdrizet.org/health
```

Expected output: `{"status":"pass"}`. If nginx returns a 502 error, Headscale
may not be running yet. Check with:
```
sudo systemctl status headscale
sudo journalctl -u headscale -n 30
```

---

## Step 2: Generate a pre-auth key (recommended)

Pre-auth keys let devices register with Headscale without requiring a URL
approval for each one. Generate a key on the VPS after Headscale is installed.

First, get the numeric user ID (Headscale v0.28 requires IDs, not usernames):
```
sudo headscale users list
```

Then create a reusable key valid for 24 hours:
```
sudo headscale preauthkeys create --user <id> --expiration 24h --reusable
```

Copy the printed key. Pass it to `install-tailscale-client.sh` on each device:
```
sudo bash scripts/install-tailscale-client.sh --auth-key <key>
```

The key expires after 24 hours. Generate a new one if it expires before use.
A reusable key can be used for multiple devices without generating a new one
each time.
Once a device has registered, the pre-auth key is no longer needed for that
device.

---

## Step 3: Approve a device node (interactive registration)

If a device was registered without a pre-auth key, the Tailscale client prints
a URL like:

```
https://headscale.perdrizet.org/register/nodekey:XXXX...
```

On the VPS, approve the node using the node key from that URL.
First, find the numeric user ID, then register the node:

```
sudo headscale users list
sudo headscale nodes register --user <id> --key nodekey:XXXX...
```

Verify the node was registered and is active:

```
headscale nodes list
```

The output should show the device with a recent "last seen" timestamp. Repeat
for each device.

---

## Step 4: Approve exit node routes

After running `scripts/configure-exit-node.sh` on the VPS, the exit node
advertises two routes: `0.0.0.0/0` (all IPv4 traffic) and `::/0` (all IPv6
traffic). These must be explicitly approved before client devices can use them.

In Headscale v0.28, route approval is done via `nodes approve-routes`. First
find the node ID, then list and approve the routes:

```
sudo headscale nodes list
sudo headscale nodes list-routes
```

The output will look similar to:

```
ID | Hostname   | Approved | Available | Serving (Primary)
1  | gatekeeper |          | 0.0.0.0/0 |
   |            |          | ::/0      |
```

Approve both exit node routes in a single command (replace `1` with the node
ID shown in `nodes list` if it differs):

```
sudo headscale nodes approve-routes --identifier 1 --routes "0.0.0.0/0,::/0"
```

Confirm the routes are now approved and serving:

```
sudo headscale nodes list-routes
```

The "Approved" and "Serving" columns should both show `0.0.0.0/0` and `::/0`.

After approval, run `scripts/configure-client.sh` on the desktop and laptop.

---

## Step 5: Configure the phone

The Tailscale mobile app supports custom control servers. Follow these steps:

1. Install the Tailscale app (iOS App Store or Google Play Store).

2. Before logging in, open the app settings:
   - On iOS: tap the Tailscale logo at the top of the home screen, then
     "Settings".
   - On Android: tap the three-dot menu, then "Settings".

3. Find the "Control server" or "Custom control server" option and enter:
   ```
   https://headscale.perdrizet.org
   ```

4. Tap "Log in". The app will open a browser window showing a URL like:
   ```
   https://headscale.perdrizet.org/register/nodekey:XXXX...
   ```

5. On the VPS, approve the phone:
   ```
   sudo headscale users list
   sudo headscale nodes register --user <id> --key nodekey:XXXX...
   ```

6. The app should show the tailnet devices as peers.

7. To activate the exit node, go to the exit node settings in the app and
   select "gatekeeper" (the VPS). The phone will route all internet traffic
   through the VPS.

---

## MagicDNS hostnames

With MagicDNS enabled in the Headscale config, devices are reachable at
`<system-hostname>.perdrizet.org` in addition to their Tailscale IP.

The hostname used in MagicDNS is the system hostname of the device at the time
of registration. Verify a device's hostname with:

```
hostname
```

Expected MagicDNS hostnames for this tailnet:

| Device           | System hostname | MagicDNS hostname               |
|------------------|-----------------|---------------------------------|
| Desktop          | pyrite          | pyrite.ts.perdrizet.org         |
| Laptop           | laptop          | laptop.ts.perdrizet.org         |
| Phone            | phone           | phone.ts.perdrizet.org          |
| VPS (gatekeeper) | gatekeeper      | gatekeeper.ts.perdrizet.org     |

If a device's system hostname does not match the expected names above, update
`/etc/hostname` and reboot before registering the device with Headscale.

---

## Troubleshooting

**Headscale does not start after install**

Inspect the service logs:
```
sudo journalctl -u headscale -n 50
```

If the journal shows "No entries", run the command with `sudo` -- the
`headscale` user's logs are only visible to root.

Common causes:
- A port is already in use. Headscale listens on `127.0.0.1:8090` (HTTP),
  `127.0.0.1:9099` (metrics), and `127.0.0.1:50443` (gRPC). Check for
  conflicts with:
  ```
  sudo ss -tlnp | grep ':8090\|:9099\|:50443'
  ```
  If a port is taken, edit the relevant variable in
  `scripts/install-headscale.sh` and update `/etc/headscale/config.yaml` and
  `/etc/nginx/sites-available/headscale` to match.
- The config key `ip_prefixes` is invalid in Headscale v0.23+. The correct
  key is `prefixes` with `v4`, `v6`, and `allocation` subkeys (the install
  script handles this automatically for new installs).
- `server_url cannot be part of base_domain`: the `base_domain` in config.yaml
  must not overlap with the `server_url` hostname. For example, if
  `server_url` is `https://headscale.perdrizet.org`, do not set
  `base_domain: perdrizet.org`. Use a distinct subdomain like
  `ts.perdrizet.org`.

**nginx returns 502 Bad Gateway for headscale.perdrizet.org**

This means nginx is running but cannot reach Headscale on
`http://127.0.0.1:8090`. Check that Headscale is running:
```
sudo systemctl status headscale
sudo journalctl -u headscale -n 20
```

Confirm that Headscale is actually bound to port 8090:
```
sudo ss -tlnp | grep 8090
```

**certbot fails to issue a certificate**

Certbot uses the HTTP-01 challenge, which requires nginx to be running and
port 80 to be reachable from the internet. Common causes:
- The DNS A record has not propagated yet. Re-check with
  `dig headscale.perdrizet.org A +short`.
- Port 80 is blocked by the firewall. Verify with `sudo ufw status`.
- Another nginx config is capturing port 80 traffic before the ACME challenge
  path. Check `/etc/nginx/sites-enabled/` for conflicting server blocks.

After resolving the cause, re-run certbot manually:
```
sudo certbot certonly --nginx -d headscale.perdrizet.org
```

Then reload nginx:
```
sudo systemctl reload nginx
```

**The TLS certificate for headscale.perdrizet.org has expired**

Certbot installs a renewal timer automatically. Verify it is active:
```
sudo systemctl status certbot.timer
```

To renew immediately:
```
sudo certbot renew
sudo systemctl reload nginx
```

**A device does not appear in `headscale nodes list`**

- Confirm `tailscale up --login-server=...` completed without errors on that
  device.
- If using interactive registration, check that the node key was approved on
  the VPS.
- Check the Headscale logs: `journalctl -u headscale -n 50`

**Exit node is active but `curl https://ifconfig.me` does not return the VPS IP**

- Verify the exit node routes are enabled: `headscale routes list`
- Confirm the client has the exit node set: `tailscale status`
- Check that IP forwarding is active on the VPS: `sysctl net.ipv4.ip_forward`
  (should return `1`).

**SSH connection refused over Tailscale IP**

- Verify the SSH daemon is running on the target device: `systemctl status sshd`
- Confirm the Tailscale IP is reachable: `ping <tailscale-ip>`
- Check that the public key was distributed: `cat ~/.ssh/authorized_keys` on
  the target device.
