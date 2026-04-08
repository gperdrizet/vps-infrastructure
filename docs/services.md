# Gatekeeper service inventory

A record of all services running on gatekeeper (74.208.107.78), the ports
they use, and any domains they are exposed on. Keep this file updated whenever
a service is added, removed, or reconfigured.

Last updated: 2026-04-05


---

## Public-facing ports

These ports are open in ufw and accept connections from the internet.

| Port  | Protocol | Service                          | Notes                                |
|-------|----------|----------------------------------|--------------------------------------|
| 22    | TCP      | sshd (default, disabled)         | Overridden by port 44441 in sshd_config |
| 80    | TCP      | nginx                            | Redirects all HTTP to HTTPS           |
| 443   | TCP      | nginx                            | HTTPS, terminates TLS for all vhosts  |
| 44441 | TCP      | sshd                             | Non-default SSH port, in /etc/ssh/sshd_config |
| 51820 | UDP      | WireGuard (wg0)                  | Peer: 73.238.241.70 (10.0.0.2/32)    |
| 54321 | TCP      | nginx TCP stream proxy           | Public internet access to remote PostgreSQL server at 10.0.0.2:5432 (via WireGuard) |


---

## nginx vhosts (all on port 443)

Traffic reaches nginx on ports 80 and 443. Port 80 redirects to HTTPS.
All domains below are served over HTTPS on port 443.

| Domain                     | Backend                  | TLS source              | Notes                                 |
|----------------------------|--------------------------|-------------------------|---------------------------------------|
| headscale.perdrizet.org    | http://127.0.0.1:8090    | Let's Encrypt (certbot) | Tailscale control server (Headscale)  |
| bench.perdrizet.org        | http://127.0.0.1:8010    | Let's Encrypt (certbot) | Docker-bench web app                  |
| staging.perdrizet.org      | http://127.0.0.1:8003    | Ionos wildcard cert     | LogKeep staging environment           |
| llm.perdrizet.org          | http://10.0.0.2:8502     | Ionos wildcard cert     | llama.cpp server on remote machine (via WireGuard) |

The nginx TCP stream proxy for port 54321 is configured directly in
/etc/nginx/nginx.conf (not in a vhost file) and provides public internet
access to a remote PostgreSQL server at 10.0.0.2:5432 via the WireGuard tunnel.

**Note:** Under upcoming reorganization plan, this will be updated to:
- Public subdomain: db.perdrizet.org:54321
- Backend: 100.64.0.2:5432 (via Tailscale, replacing WireGuard)
- llm.perdrizet.org will replace gpt.perdrizet.org


---

## Localhost-only ports

These ports are bound to 127.0.0.1 or a container network and are not
directly reachable from the internet.

### Headscale

| Port  | Protocol | Service                   |
|-------|----------|---------------------------|
| 3001  | TCP/HTTP | Headplane (Headscale web UI) |
| 8090  | TCP/HTTP | Headscale main listener   |
| 9099  | TCP/HTTP | Headscale Prometheus metrics |
| 50443 | TCP/gRPC | Headscale gRPC endpoint   |

### Docker containers (logkeep stack)

| Port  | Container                  | Service                     |
|-------|----------------------------|-----------------------------|
| 3000  | logkeep-grafana            | Grafana dashboard           |
| 3100  | logkeep-loki               | Loki log aggregator         |
| 5432  | logkeep-postgres           | PostgreSQL database         |
| 8001  | logkeep-blue               | LogKeep blue (production)   |
| 8002  | logkeep-green              | LogKeep green (production)  |
| 8003  | logkeep-staging            | LogKeep staging             |
| 8080  | logkeep-cadvisor           | cAdvisor container metrics  |
| 9090  | logkeep-prometheus         | Prometheus metrics collector |
| 9093  | logkeep-alertmanager       | Alertmanager                |
| 9100  | logkeep-node-exporter      | Node exporter (host metrics)|
| 9113  | logkeep-nginx-exporter     | nginx Prometheus exporter   |
| 9187  | logkeep-postgres-exporter  | Postgres Prometheus exporter|
| N/A   | logkeep-promtail           | Promtail log shipper        |

### Docker containers (docker-bench stack)

| Port  | Container                 | Service                     |
|-------|---------------------------|--------------------------|
| 8010  | docker-bench-web-1        | Docker-bench web app     |
| 5432  | docker-bench-postgres-1   | PostgreSQL (internal)    |
| 8000  | docker-bench-celery-1     | Celery worker (internal) |
| 8000  | docker-bench-celery-beat-1| Celery beat (internal)   |
| 6379  | docker-bench-redis-1      | Redis (internal)         |


---

## WireGuard

Interface: wg0
Listen port: 51820
Peer endpoint: 73.238.241.70:60157
Peer allowed IPs: 10.0.0.2/32

The peer at 10.0.0.2 hosts:
- llama.cpp server (port 8502) - proxied via gpt.perdrizet.org
- PostgreSQL server (port 5432) - accessible via nginx TCP proxy on port 54321


---

## Tailscale Network

**Control Server:** Headscale at headscale.perdrizet.org  
**MagicDNS Domain:** ts.perdrizet.org

| Device     | Hostname   | Tailscale IP | Status | Role |
|------------|------------|--------------|--------|------|
| VPS        | gatekeeper | 100.64.0.1   | idle   | Exit node (advertised) |
| Desktop    | pyrite     | 100.64.0.2   | active | Client (exit node enabled) |
| Laptop     | laptop     | 100.64.0.3   | active | Client |
| Phone      | voxxel     | 100.64.0.4   | varies | Android client |

All client devices route internet traffic through the VPS exit node (100.64.0.1).
SSH between Linux devices uses Tailscale IPs or MagicDNS hostnames (e.g., gatekeeper.ts.perdrizet.org).

---

## SSH reverse tunnel (DEPRECATED - To be removed)

Port 11434 on 0.0.0.0 is held by an active SSH session (sshd process owned by
siderealyear, not a standalone daemon). This is a remote port forward created
by a connected client, exposing port 11434 on the VPS and tunnelling it back
to the client machine (mendel). Port 11434 is typically used by Ollama, but
there is no Ollama service running in this infrastructure.

This port is not open in ufw and is not proxied by nginx. It is only accessible
while the SSH session that created the tunnel is active.

**DEPRECATED:** This SSH reverse tunnel is unused and will be removed during
infrastructure reorganization.

**Action:** Remove SSH -R tunnel command (if present) from laptop startup scripts
during Phase 3 migration.


---

## DNS-only records on perdrizet.org

These subdomains do not have a corresponding open port on this machine but
are configured at the DNS level or in /etc/hosts for internal routing.

| Record                  | Type | Value           | Notes                           |
|-------------------------|------|-----------------|---------------------------------|
| headscale.perdrizet.org | A    | 74.208.107.78   | Points to this VPS              |
| bench.perdrizet.org     | A    | 74.208.107.78   | Points to this VPS              |
| staging.perdrizet.org   | A    | 74.208.107.78   | Points to this VPS              |
| gpt.perdrizet.org       | A    | 74.208.107.78   | Points to this VPS, proxied to WireGuard peer |
