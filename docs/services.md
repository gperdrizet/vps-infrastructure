# Gatekeeper service inventory

A record of all services running on gatekeeper (74.208.107.78), the ports
they use, and any domains they are exposed on. Keep this file updated whenever
a service is added, removed, or reconfigured.

Last updated: 2026-06-10 (added feedback, admin, nixx, site-staging, model-gateway-staging, bench-staging; updated logkeep and staging status)


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

| Domain                       | Backend                    | TLS source              | Notes                                 |
|------------------------------|----------------------------|-------------------------|---------------------------------------|
| perdrizet.org                | redirect                   | Let's Encrypt (certbot) | Redirects to logkeep.perdrizet.org    |
| www.perdrizet.org            | redirect                   | Let's Encrypt (certbot) | Redirects to logkeep.perdrizet.org    |
| logkeep.perdrizet.org        | http://127.0.0.1:8000      | Let's Encrypt (certbot) | LogKeep production (blue/green deploy); **currently down** — mid-update |
| staging.perdrizet.org        | http://100.64.0.1:8003     | Let's Encrypt (certbot) | LogKeep staging (Tailscale-only access) |
| feedback.perdrizet.org       | http://127.0.0.1:18080     | Let's Encrypt (certbot) | Feedback/contact form app (Django)    |
| admin.perdrizet.org          | http://127.0.0.1:8600      | Let's Encrypt (certbot) | Site admin agent (LLM-backed, systemd service) |
| nixx.perdrizet.org           | http://100.64.0.2:8000     | Let's Encrypt (certbot) | Personal assistant/memory PWA (proxies to pyrite) |
| site-staging.perdrizet.org   | /opt/perdrizet.org-staging | Let's Encrypt (certbot) | Staging for perdrizet.org personal brand site (static Astro build) |
| bench.perdrizet.org          | http://127.0.0.1:8010      | Let's Encrypt (certbot) | Bench web app                         |
| model.perdrizet.org          | http://127.0.0.1:8503      | Let's Encrypt (certbot) | model-gateway (legacy domain; replaced by promptlyapi.com) |
| headscale.perdrizet.org      | http://127.0.0.1:8090      | Let's Encrypt (certbot) | Tailscale control server (Headscale)  |
| headplane.perdrizet.org      | http://127.0.0.1:3001      | Let's Encrypt (certbot) | Headscale web UI                      |
| grafana.perdrizet.org        | http://127.0.0.1:3000      | Let's Encrypt (certbot) | Grafana monitoring dashboard          |
| code.perdrizet.org           | http://127.0.0.1:47301     | Let's Encrypt (certbot) | OpenVSCode Server on pyrite (via autossh tunnel); nginx basic auth |
| jupyter.perdrizet.org        | http://127.0.0.1:47302     | Let's Encrypt (certbot) | JupyterLab on pyrite (via autossh tunnel); JupyterLab built-in auth |
| bug-hunter.perdrizet.org     | http://127.0.0.1:8509      | Let's Encrypt (certbot) | Bug Hunter web app (production)       |
| promptlyapi.com              | http://127.0.0.1:8503      | Let's Encrypt (certbot) | model-gateway primary public domain (authenticated API gateway; proxies to llama.cpp on pyrite) |

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

| Port  | Container                    | Service                      |
|-------|------------------------------|------------------------------|
| 3000  | monitoring-grafana           | Grafana dashboard            |
| 3100  | monitoring-loki              | Loki log aggregator          |
| 8080  | monitoring-cadvisor          | cAdvisor container metrics   |
| 9090  | monitoring-prometheus        | Prometheus metrics collector |
| 9093  | monitoring-alertmanager      | Alertmanager                 |
| 9100  | monitoring-node-exporter     | Node exporter (host metrics) |
| 9115  | monitoring-blackbox-exporter | Blackbox exporter (SSL/HTTP) |
| N/A   | monitoring-promtail          | Promtail log shipper         |

### Docker containers (logkeep stack)

Managed by `/opt/logkeep/docker/` (project: `logkeep`).
- Production services defined in `docker-compose.prod.yml` (blue/green deploy)
- Staging managed separately at `/opt/logkeep-staging/` with its own postgres

| Port                | Container                  | Service                      |
|---------------------|----------------------------|------------------------------|
| 127.0.0.1:5432      | logkeep-postgres           | PostgreSQL database (prod)   |
| 127.0.0.1:8001      | logkeep-blue               | LogKeep blue (production) **[STOPPED — mid-update]** |
| 127.0.0.1:8002      | logkeep-green              | LogKeep green (production) **[STOPPED — mid-update]** |
| 127.0.0.1:9187      | logkeep-postgres-exporter  | Postgres Prometheus exporter |
| 100.64.0.1:8003     | logkeep-staging            | LogKeep staging (Tailscale-only) |
| 5432 (internal)     | logkeep-postgres-staging   | PostgreSQL for staging       |

### Docker containers (model-gateway stack)

Managed by `/opt/model-gateway/docker-compose.yml` (project: `model-gateway`).
An authenticated, metered API gateway for the llama.cpp server running on pyrite.
Users register at `/register` and receive a trial allocation (500k tokens, 14 days).
API calls use Bearer tokens and are OpenAI SDK-compatible. Token top-ups via Stripe or BTCPay.

**Production** (`/opt/model-gateway/`):

| Port              | Container              | Service                                    |
|-------------------|------------------------|--------------------------------------------||
| 127.0.0.1:8503    | model-gateway-api      | FastAPI gateway (uvicorn)                  |
| 5432 (internal)   | model-gateway-db       | PostgreSQL (users, balances, usage events) |
| 100.64.0.1:8504   | model-gateway-adminer  | Adminer DB UI (Tailscale-only)             |

**Staging** (`/opt/model-gateway-staging/`, Tailscale-only):

| Port              | Container                    | Service                                    |
|-------------------|------------------------------|--------------------------------------------||
| 100.64.0.1:8505   | model-gateway-api-staging    | FastAPI gateway staging                    |
| 5432 (internal)   | model-gateway-db-staging     | PostgreSQL (staging)                       |
| 100.64.0.1:8506   | model-gateway-adminer-staging| Adminer DB UI (staging, Tailscale-only)    |

### Docker containers (bug-hunter stack)

Managed by `/opt/bug-hunter/` (project: `bug-hunter`) and `/opt/bug-hunter-staging/` (project: `bug-hunter-staging`).
FastAPI backend + frontend web app. Staging is Tailscale-only (no public nginx vhost).

| Port               | Container                     | Service                          |
|--------------------|-------------------------------|----------------------------------|
| 127.0.0.1:8509     | bug-hunter-frontend-1         | Frontend (production)            |
| 8000 (internal)    | bug-hunter-backend-1          | FastAPI backend (production)     |
| 5432 (internal)    | bug-hunter-db-1               | PostgreSQL (production)          |
| 100.64.0.1:8507    | bug-hunter-staging-frontend-1 | Frontend (staging, Tailscale-only) |
| 8000 (internal)    | bug-hunter-staging-backend-1  | FastAPI backend (staging)        |
| 5432 (internal)    | bug-hunter-staging-db-1       | PostgreSQL (staging)             |

### Docker containers (BTCPay stack)

Managed by `~/vps-infrastructure/compose/docker-compose.btcpay.yml` (project: `compose`).
BTCPay Server for Bitcoin payment processing. Accessible at `100.64.0.1:23000` (Tailscale-only).
`compose-btcd-1` is a Bitcoin full node — it maintains a copy of the blockchain and uses ~500MB–1GB RAM.
**Currently stopped** (2026-05-24) — not in active use. To restart: `cd ~/vps-infrastructure/compose && docker compose -f docker-compose.btcpay.yml up -d`

| Port                  | Container          | Service                                     |
|-----------------------|--------------------|---------------------------------------------|
| 100.64.0.1:23000      | compose-btcpay-1   | BTCPay Server UI                            |
| 8332-8333 (internal)  | compose-btcd-1     | Bitcoin full node (~500MB–1GB RAM)          |
| 32838 (internal)      | compose-nbxplorer-1| NBXplorer blockchain indexer                |
| 5432 (internal)       | compose-btcpay-db-1| PostgreSQL (BTCPay + NBXplorer data)        |

### Docker containers (bench stack)

Managed by `/opt/bench/docker/docker-compose.prod.yml` (project: `bench`).

**Production**:

| Port                | Container                  | Service                      |
|---------------------|----------------------------|-----------------------------||
| 127.0.0.1:8010      | bench-web                  | Bench web app                |
| 5432 (internal)     | bench-postgres             | PostgreSQL                   |
| N/A                 | bench-celery               | Celery worker                |
| N/A                 | bench-celery-beat          | Celery beat                  |
| 6379 (internal)     | bench-redis                | Redis                        |
| 127.0.0.1:9188      | bench-postgres-exporter    | Postgres Prometheus exporter |

**Staging** (`/opt/bench-staging/`, Tailscale-only at `100.64.0.1:8012`):

| Port                | Container                  | Service                      |
|---------------------|----------------------------|------------------------------|
| 127.0.0.1:8011      | bench-web-staging          | Bench staging app            |
| 5432 (internal)     | bench-postgres-staging     | PostgreSQL (staging)         |
| N/A                 | bench-celery-staging       | Celery worker (staging)      |
| N/A                 | bench-celery-beat-staging  | Celery beat (staging)        |
| 6379 (internal)     | bench-redis-staging        | Redis (staging)              |

Nginx listens on `100.64.0.1:8012` (Tailscale IP) for staging — no public domain.

### Services on host (non-Docker)

| Port             | Service                  | Notes                                                    |
|------------------|--------------------------|----------------------------------------------------------|
| 127.0.0.1:8600   | perdrizet-admin (systemd)| Site admin agent — uvicorn, `/opt/perdrizet.org-admin/`  |

### Docker containers (feedback stack)

Managed by `/opt/feedback/docker-compose.prod.yml` (project: `feedback`).
Django feedback/contact form app for perdrizet.org.

| Port                | Container          | Service                      |
|---------------------|--------------------|------------------------------|
| 127.0.0.1:18080     | feedback-app-1     | Django app (gunicorn)        |
| N/A                 | feedback-worker-1  | Celery worker                |
| 5432 (internal)     | feedback-db-1      | PostgreSQL                   |


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
| perdrizet.org                | A    | 74.208.107.78   | Redirects to logkeep subdomain          |
| www.perdrizet.org            | A    | 74.208.107.78   | Redirects to logkeep subdomain          |
| logkeep.perdrizet.org        | A    | 74.208.107.78   | LogKeep production                      |
| staging.perdrizet.org        | A    | 74.208.107.78   | LogKeep staging (Tailscale-only)        |
| feedback.perdrizet.org       | A    | 74.208.107.78   | Feedback/contact app                    |
| admin.perdrizet.org          | A    | 74.208.107.78   | Site admin agent                        |
| nixx.perdrizet.org           | A    | 74.208.107.78   | Personal assistant PWA (proxies to pyrite) |
| site-staging.perdrizet.org   | A    | 74.208.107.78   | Staging for perdrizet.org static site   |
| bench.perdrizet.org          | A    | 74.208.107.78   | Bench web app                           |
| model.perdrizet.org          | A    | 74.208.107.78   | model-gateway (legacy; replaced by promptlyapi.com) |
| headscale.perdrizet.org      | A    | 74.208.107.78   | Tailscale control server                |
| headplane.perdrizet.org      | A    | 74.208.107.78   | Headscale web UI                        |
| grafana.perdrizet.org        | A    | 74.208.107.78   | Monitoring dashboard                    |
| code.perdrizet.org           | A    | 74.208.107.78   | OpenVSCode Server (remote dev)          |
| jupyter.perdrizet.org        | A    | 74.208.107.78   | JupyterLab (remote dev)                 |
| bug-hunter.perdrizet.org     | A    | 74.208.107.78   | Bug Hunter web app                      |

**External domains (non-perdrizet.org)**

| Record          | Type | Value         | Notes                                     |
|-----------------|------|---------------|-------------------------------------------|
| promptlyapi.com | A    | 74.208.107.78 | Primary public domain for model-gateway (replaces model.perdrizet.org) |