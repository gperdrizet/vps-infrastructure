# Gatekeeper service inventory

A record of all services running on gatekeeper (74.208.107.78), the ports
they use, and any domains they are exposed on. Keep this file updated whenever
a service is added, removed, or reconfigured.

Last updated: 2026-04-20


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
| model.perdrizet.org        | http://100.64.0.2:8502   | Let's Encrypt (certbot) | llama.cpp server on pyrite (via Tailscale) |
| headscale.perdrizet.org    | http://127.0.0.1:8090    | Let's Encrypt (certbot) | Tailscale control server (Headscale)  |
| headplane.perdrizet.org    | http://127.0.0.1:3001    | Let's Encrypt (certbot) | Headscale web UI                      |
| grafana.perdrizet.org      | http://127.0.0.1:3000    | Let's Encrypt (certbot) | Grafana monitoring dashboard          |

The nginx TCP stream proxy for port 54321 is configured directly in
/etc/nginx/nginx.conf (not in a vhost file) and provides public internet
access to a remote PostgreSQL server at 100.64.0.2:5432 via Tailscale.

Blue/green deployment for LogKeep uses a symlink at
`/etc/nginx/conf.d/logkeep.conf` → `/etc/nginx/logkeep-configs/{blue,green}.conf`.


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

Managed by `/opt/logkeep/docker/docker-compose.prod.yml` and
`docker-compose.staging.yml`.

| Port  | Container                  | Service                     |
|-------|----------------------------|-----------------------------|
| 5432  | logkeep-postgres           | PostgreSQL database         |
| 8001  | logkeep-blue               | LogKeep blue (production)   |
| 8002  | logkeep-green              | LogKeep green (production)  |
| 8003  | logkeep-staging            | LogKeep staging             |
| 9113  | logkeep-nginx-exporter     | nginx Prometheus exporter   |
| 9187  | logkeep-postgres-exporter  | Postgres Prometheus exporter|

### Docker containers (bench stack)

Managed by `/opt/bench/docker/docker-compose.prod.yml`.

| Port  | Container                 | Service                  |
|-------|---------------------------|--------------------------|
| 8010  | docker-bench-web-1        | Docker-bench web app     |
| 5432  | docker-bench-postgres-1   | PostgreSQL (internal)    |
| N/A   | docker-bench-celery-1     | Celery worker (internal) |
| N/A   | docker-bench-celery-beat-1| Celery beat (internal)   |
| 6379  | docker-bench-redis-1      | Redis (internal)         |


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
- llama.cpp server (port 8502) - proxied via model.perdrizet.org
- PostgreSQL server (port 5432) - accessible via nginx TCP proxy on port 54321

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
| model.perdrizet.org        | A    | 74.208.107.78   | LLM proxy to pyrite             |
| headscale.perdrizet.org    | A    | 74.208.107.78   | Tailscale control server        |
| headplane.perdrizet.org    | A    | 74.208.107.78   | Headscale web UI                |
| grafana.perdrizet.org      | A    | 74.208.107.78   | Monitoring dashboard           