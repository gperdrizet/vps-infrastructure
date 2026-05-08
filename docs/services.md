# Gatekeeper service inventory

A record of all services running on gatekeeper (74.208.107.78), the ports
they use, and any domains they are exposed on. Keep this file updated whenever
a service is added, removed, or reconfigured.

Last updated: 2026-05-08 (model-gateway: replaced direct llama.cpp proxy with authenticated API gateway container)


---

## Public-facing ports

These ports are open in ufw and accept connections from the internet.

| Port  | Protocol | Service                          | Notes                                |
|-------|----------|----------------------------------|--------------------------------------|
| 22    | TCP      | sshd (default, disabled)         | Overridden by port 44441 in sshd_config |
| 80    | TCP      | nginx                            | Redirects all HTTP to HTTPS           |
| 443   | TCP      | nginx                            | HTTPS, terminates TLS for all vhosts  |
| 44441 | TCP      | sshd                             | Non-default SSH port, in /etc/ssh/sshd_config |
| 54321 | TCP      | nginx TCP stream proxy           | Public internet access to remote PostgreSQL server at 100.64.0.2:5432 (via Tailscale) |


---

## nginx vhosts (all on port 443)

Traffic reaches nginx on ports 80 and 443. Port 80 redirects to HTTPS.
All domains below are served over HTTPS on port 443.

| Domain                     | Backend                  | TLS source              | Notes                                 |
|----------------------------|--------------------------|-------------------------|---------------------------------------|
| perdrizet.org              | redirect                 | Let's Encrypt (certbot) | Redirects to logkeep.perdrizet.org    |
| www.perdrizet.org          | redirect                 | Let's Encrypt (certbot) | Redirects to logkeep.perdrizet.org    |
| logkeep.perdrizet.org      | http://127.0.0.1:8001    | Let's Encrypt (certbot) | LogKeep production (blue/green deploy)|
| bench.perdrizet.org        | http://127.0.0.1:8010    | Let's Encrypt (certbot) | Docker-bench web app                  |
| staging.perdrizet.org      | http://127.0.0.1:8003    | Let's Encrypt (certbot) | LogKeep staging environment           |
| model.perdrizet.org        | http://127.0.0.1:8503    | Let's Encrypt (certbot) | model-gateway container (authenticated API gateway; proxies to llama.cpp on pyrite) |
| headscale.perdrizet.org    | http://127.0.0.1:8090    | Let's Encrypt (certbot) | Tailscale control server (Headscale)  |
| headplane.perdrizet.org    | http://127.0.0.1:3001    | Let's Encrypt (certbot) | Headscale web UI                      |
| grafana.perdrizet.org      | http://127.0.0.1:3000    | Let's Encrypt (certbot) | Grafana monitoring dashboard          |
| code.perdrizet.org         | http://127.0.0.1:47301   | Let's Encrypt (certbot) | OpenVSCode Server on pyrite (via autossh tunnel); nginx basic auth |
| jupyter.perdrizet.org      | http://127.0.0.1:47302   | Let's Encrypt (certbot) | JupyterLab on pyrite (via autossh tunnel); JupyterLab built-in auth |

The nginx TCP stream proxy for port 54321 is configured directly in
/etc/nginx/nginx.conf (not in a vhost file) and provides public internet
access to a remote PostgreSQL server at 100.64.0.2:5432 via Tailscale.

The reverse proxies for code.perdrizet.org and jupyter.perdrizet.org forward
to localhost ports that are kept open by an autossh reverse tunnel from pyrite
(`dev-tunnel.service` on pyrite). See `tailnet/scripts/setup-dev-server.sh`
for service definitions.

`vscode.dev/tunnel/pyrite` provides an alternative browser-based VS Code
access path via the Microsoft relay service (`vscode-tunnel.service` on
pyrite). This route supports the full Microsoft Extension Marketplace,
including GitHub Copilot, which is unavailable on code.perdrizet.org
(Open VSX registry only). Authentication uses the `gperdrizet` GitHub account.

Blue/green deployment for LogKeep uses a symlink at
`/etc/nginx/conf.d/logkeep.conf` → `/etc/nginx/logkeep-configs/{blue,green}.conf`.


---

## Localhost-only ports

These ports are bound to 127.0.0.1 or a container network and are not
directly reachable from the internet.

### Pyrite reverse tunnel endpoints (on VPS, bound to 127.0.0.1)

These ports are created by the autossh reverse tunnel (`dev-tunnel.service`
running on pyrite). They are only reachable via nginx on the VPS.

| Port  | Forwards to          | Service               |
|-------|----------------------|-----------------------|
| 47301 | pyrite:47301         | OpenVSCode Server     |
| 47302 | pyrite:47302         | JupyterLab            |

**VS Code Tunnel** (`vscode-tunnel.service` on pyrite) connects outbound to
the Microsoft relay — no VPS port is involved. Accessible at
`https://vscode.dev/tunnel/pyrite`.

### Headscale

| Port  | Protocol | Service                   |
|-------|----------|---------------------------|
| 3001  | TCP/HTTP | Headplane (Headscale web UI) |
| 8090  | TCP/HTTP | Headscale main listener   |
| 9099  | TCP/HTTP | Headscale Prometheus metrics |
| 50443 | TCP/gRPC | Headscale gRPC endpoint   |

### Docker containers (monitoring stack)

Managed by `/srv/infra/docker-compose.monitoring.yml`.

| Port  | Container                    | Service                     |
|-------|------------------------------|-----------------------------|
| 3000  | monitoring-grafana           | Grafana dashboard           |
| 3100  | monitoring-loki              | Loki log aggregator         |
| 8080  | monitoring-cadvisor          | cAdvisor container metrics  |
| 9090  | monitoring-prometheus        | Prometheus metrics collector |
| 9093  | monitoring-alertmanager      | Alertmanager                |
| 9100  | monitoring-node-exporter     | Node exporter (host metrics)|
| 9115  | monitoring-blackbox-exporter | Blackbox exporter (SSL/HTTP)|
| N/A   | monitoring-promtail          | Promtail log shipper        |

### Docker containers (logkeep stack)

Managed by `/opt/logkeep/docker/` (project: `logkeep`).
- Production services defined in `docker-compose.prod.yml`
- Staging services defined in `docker-compose.staging.yml`

| Port  | Container                  | Service                     |
|-------|----------------------------|-----------------------------|
| 5432  | logkeep-postgres           | PostgreSQL database         |
| 8001  | logkeep-blue               | LogKeep blue (production)   |
| 8002  | logkeep-green              | LogKeep green (production)  |
| 8003  | logkeep-staging            | LogKeep staging             |
| 9187  | logkeep-postgres-exporter  | Postgres Prometheus exporter|

### Docker containers (model-gateway stack)

Managed by `/opt/model-gateway/docker-compose.yml` (project: `model-gateway`).
An authenticated, metered API gateway for the llama.cpp server running on pyrite.
Users register at `/register` and receive a trial allocation (500k tokens, 14 days).
API calls use Bearer tokens and are OpenAI SDK-compatible. Token top-ups via Stripe or BTCPay.

| Port              | Container                    | Service                                    |
|-------------------|------------------------------|--------------------------------------------|
| 127.0.0.1:8503    | model-gateway-gateway-1      | FastAPI gateway (uvicorn)                  |
| 5432 (internal)   | model-gateway-db-1           | PostgreSQL (users, balances, usage events) |
| 100.64.0.1:8504   | model-gateway-adminer-1      | Adminer DB UI (Tailscale-only)             |

### Docker containers (bench stack)

Managed by `/opt/bench/docker/docker-compose.prod.yml` (project: `bench`).

| Port  | Container                  | Service                  |
|-------|----------------------------|--------------------------|
| 8010  | bench-web                  | Bench web app            |
| 5432  | bench-postgres             | PostgreSQL (internal)    |
| N/A   | bench-celery               | Celery worker (internal) |
| N/A   | bench-celery-beat          | Celery beat (internal)   |
| 6379  | bench-redis                | Redis (internal)         |
| 9188  | bench-postgres-exporter    | Postgres Prometheus exporter |


---

## Tailscale Network

**Control Server:** Headscale at headscale.perdrizet.org
**MagicDNS Domain:** ts.perdrizet.org

| Device     | Hostname   | Tailscale IP | Status | Role |
|------------|------------|--------------|--------|------|
| VPS        | gatekeeper | 100.64.0.1   | idle   | Exit node (advertised) |
| Desktop    | pyrite     | 100.64.0.2   | active | Client (exit node enabled) |
| Laptop     | laptop     | 100.64.0.3   | varies | Client |
| Phone      | voxxel     | 100.64.0.4   | varies | Android client |

All client devices route internet traffic through the VPS exit node (100.64.0.1).
SSH between Linux devices uses Tailscale IPs or MagicDNS hostnames (e.g., gatekeeper.ts.perdrizet.org).

The peer at 100.64.0.2 (pyrite) hosts:
- llama.cpp server (port 8502) - backend for model-gateway (accessed from gatekeeper over Tailscale)
- PostgreSQL server (port 5432) - accessible via nginx TCP proxy on port 54321
- OpenVSCode Server (port 47301) - tunneled to VPS via autossh, proxied via code.perdrizet.org
- JupyterLab (port 47302) - tunneled to VPS via autossh, proxied via jupyter.perdrizet.org
- VS Code Tunnel - outbound Microsoft relay connection, accessible at vscode.dev/tunnel/pyrite (full marketplace + Copilot)

**Note:** WireGuard (wg0) has been decommissioned. All remote connectivity
now uses Tailscale.


---

## DNS records on perdrizet.org

| Record                     | Type | Value           | Notes                           |
|----------------------------|------|-----------------|---------------------------------|
| perdrizet.org              | A    | 74.208.107.78   | Redirects to logkeep subdomain  |
| www.perdrizet.org          | A    | 74.208.107.78   | Redirects to logkeep subdomain  |
| logkeep.perdrizet.org      | A    | 74.208.107.78   | LogKeep production              |
| bench.perdrizet.org        | A    | 74.208.107.78   | Bench web app                   |
| staging.perdrizet.org      | A    | 74.208.107.78   | LogKeep staging                 |
| model.perdrizet.org        | A    | 74.208.107.78   | model-gateway (authenticated LLM API) |
| headscale.perdrizet.org    | A    | 74.208.107.78   | Tailscale control server        |
| headplane.perdrizet.org    | A    | 74.208.107.78   | Headscale web UI                |
| grafana.perdrizet.org      | A    | 74.208.107.78   | Monitoring dashboard            |
| code.perdrizet.org         | A    | 74.208.107.78   | OpenVSCode Server (remote dev)  |
| jupyter.perdrizet.org      | A    | 74.208.107.78   | JupyterLab (remote dev)         |