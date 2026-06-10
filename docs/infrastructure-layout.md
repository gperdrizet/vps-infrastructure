# VPS Infrastructure Layout

## Overview
Current VPS organization after Phase 1-3C (Monitoring Separation, Backups, Nginx Complete)

## Directory Structure

```
/srv/
├── infra/                    # Central infrastructure (NEW)
│   ├── configs/             # Configuration files
│   │   ├── prometheus.yml
│   │   ├── alert-rules.yml
│   │   ├── grafana-datasources.yml
│   │   ├── grafana-dashboards/
│   │   ├── loki-config.yml
│   │   ├── promtail-config.yml
│   │   ├── alertmanager.yml
│   │   └── blackbox.yml
│   ├── data/                # Persistent data
│   │   └── monitoring/
│   │       ├── prometheus/  (1.6GB)
│   │       ├── grafana/     (42MB)
│   │       ├── loki/        (9GB)
│   │       └── alertmanager/ (4KB)
│   ├── logs/                # Infrastructure logs
│   ├── scripts/             # Management scripts
│   ├── docs/                # Documentation
│   │   └── backup-improvements.md
│   └── docker-compose.monitoring.yml  # Monitoring stack
│
└── backups/                 # Database backups
    ├── backup-databases.sh  # Daily backup script (cron: 2 AM)
    ├── logkeep_*.sql.gz     # LogKeep production backups (26KB)
    ├── logkeep_staging_*.sql.gz  # Staging backups (3.4KB)
    └── bench_*.sql.gz       # Bench app backups (16KB)

/opt/
├── logkeep/                 # LogKeep application
│   ├── src/                 # Python application code
│   ├── docker/              # Docker compose files
│   │   ├── docker-compose.prod.yml
│   │   ├── docker-compose.staging.yml
│   │   ├── .env.production
│   │   └── .env.staging
│   ├── nginx/               # Nginx configs for app
│   └── scripts/             # App management scripts
│
├── model-gateway/           # model-gateway application
│   ├── app/                 # FastAPI application code
│   ├── docker-compose.yml   # Production stack
│   ├── .env                 # Runtime secrets (DATABASE_URL, LLAMA_BASE_URL, etc.)
│   └── .env.template        # Secret key reference
│
└── bench/                   # Bench application
    ├── src/                 # Application code
    └── docker/              # Docker compose files
        ├── docker-compose.yml          # Development
        ├── docker-compose.prod.yml     # Production (active)
        └── .env.production

/opt/bug-hunter/                 # Bug Hunter application (production)
    ├── backend/             # FastAPI application code
    ├── frontend/            # Frontend code
    ├── docker-compose.yml   # Base compose
    └── docker-compose.prod.yml  # Production overrides (port 127.0.0.1:8509)

/opt/bug-hunter-staging/         # Bug Hunter staging
    └── docker-compose.staging.yml  # Staging overrides (port 100.64.0.1:8507)

/opt/feedback/                   # Feedback/contact form app (Django)
    ├── docker-compose.prod.yml  # Production stack (port 127.0.0.1:18080)
    └── deploy/

/opt/perdrizet.org-admin/        # Site admin agent (systemd: perdrizet-admin)
    ├── server.py            # FastAPI/uvicorn app (port 127.0.0.1:8600)
    ├── admin.service        # systemd unit (copy to /etc/systemd/system/)
    └── .venv/

/opt/perdrizet.org-staging/      # Static staging site for perdrizet.org (Astro build)

/opt/model-gateway-staging/      # model-gateway staging instance
    ├── docker-compose.staging.yml  # Staging stack (Tailscale-only: 100.64.0.1:8505-8506)
    └── app/

/opt/logkeep-staging/            # LogKeep staging (separate repo/deployment)
    └── docker/              # docker-compose.staging.yml (Tailscale-only: 100.64.0.1:8003)

/opt/bench-staging/              # Bench staging
    └── docker/              # Staging compose (Tailscale-only via nginx 100.64.0.1:8012)

/opt/spark/                      # Apache Spark — DECOMMISSIONED (failed experiment)

/etc/nginx/
├── conf.d/
│   ├── admin.conf               # admin.perdrizet.org (-> 127.0.0.1:8600, perdrizet-admin service)
│   ├── bench.conf               # Bench app (-> 127.0.0.1:8010)
│   ├── bench-staging.conf       # Bench staging (100.64.0.1:8012, Tailscale-only)
│   ├── bug-hunter.conf          # Bug Hunter (-> 127.0.0.1:8509)
│   ├── code.conf                # OpenVSCode Server (-> 127.0.0.1:47301)
│   ├── feedback.conf            # Feedback app (-> 127.0.0.1:18080)
│   ├── grafana.conf             # Grafana (-> 127.0.0.1:3000)
│   ├── headplane.conf           # Headplane (-> 127.0.0.1:3001)
│   ├── headscale.conf           # Headscale (-> 127.0.0.1:8090)
│   ├── jupyter.conf             # JupyterLab (-> 127.0.0.1:47302)
│   ├── logkeep.conf             # Symlink -> /etc/nginx/logkeep-configs/blue.conf
│   ├── model.conf               # model-gateway proxy (-> 127.0.0.1:8503, legacy)
│   ├── nixx.conf                # nixx.perdrizet.org (-> pyrite:8000/8001 via Tailscale)
│   ├── perdrizet.conf           # Root domain redirect
│   ├── promptlyapi.conf         # promptlyapi.com (-> 127.0.0.1:8503)
│   ├── site-staging.conf        # site-staging.perdrizet.org (static, /opt/perdrizet.org-staging)
│   └── staging.conf             # LogKeep staging (-> 100.64.0.1:8003, Tailscale-only access)
├── logkeep-configs/
│   ├── blue.conf                # LogKeep blue (-> 127.0.0.1:8000)
│   └── green.conf               # LogKeep green (-> 127.0.0.1:8002)
└── snippets/
    └── security-headers.conf    # Shared security headers

/home/siderealyear/
└── vps-infrastructure/      # Git repository (version control)
    ├── configs/
    │   └── monitoring/      # Monitoring configs (Phase 2)
    ├── scripts/
    │   └── health-check.sh  # Health monitoring (Phase 1)
    └── docker-compose.core.yml  # OLD, not in use
```

## Services Running

### Monitoring (Port 127.0.0.1:*)
- **monitoring-prometheus** (9090) - Metrics collection, 30-day retention
- **monitoring-grafana** (3000) - Dashboards and visualization
- **monitoring-loki** (3100) - Log aggregation
- **monitoring-alertmanager** (9093) - Alert routing to email
- **monitoring-promtail** - Log shipping to Loki
- **monitoring-node-exporter** (9100) - System metrics
- **monitoring-cadvisor** (8080) - Container metrics
- **monitoring-blackbox-exporter** (9115) - SSL cert / endpoint monitoring

### Applications
- **logkeep-blue** (8001) - LogKeep production (blue slot) **[STOPPED — pending major update]**
- **logkeep-green** (8002) - LogKeep production (green slot) **[STOPPED — pending major update]**
- **logkeep-staging** (100.64.0.1:8003) - LogKeep staging (Tailscale-only)
- **logkeep-postgres-staging** - PostgreSQL for logkeep staging (separate from prod)
- **feedback-app-1** (127.0.0.1:18080) - Feedback/contact app (Django, `/opt/feedback/`)
- **feedback-worker-1** - Celery worker for feedback app
- **feedback-db-1** - PostgreSQL for feedback app
- **perdrizet-admin** (127.0.0.1:8600) - Site admin agent, systemd service (`/opt/perdrizet.org-admin/`)
- **bench-web** (127.0.0.1:8010) - Bench web application
- **bench-celery** - Bench background tasks
- **bench-celery-beat** - Bench scheduled tasks
- **bench-web-staging** (127.0.0.1:8011) - Bench staging (served via nginx on 100.64.0.1:8012, Tailscale-only)
- **bench-celery-staging** - Bench staging background tasks
- **bench-celery-beat-staging** - Bench staging scheduled tasks
- **model-gateway-api** (127.0.0.1:8503) - Authenticated API gateway for llama.cpp on pyrite
- **model-gateway-db** - PostgreSQL for model-gateway (users, token balances, usage)
- **model-gateway-adminer** (100.64.0.1:8504) - Adminer DB UI (Tailscale-only)
- **model-gateway-api-staging** (100.64.0.1:8505) - model-gateway staging (Tailscale-only)
- **model-gateway-db-staging** - PostgreSQL for model-gateway staging
- **model-gateway-adminer-staging** (100.64.0.1:8506) - Adminer staging UI (Tailscale-only)
- **bug-hunter-frontend-1** (127.0.0.1:8509) - Bug Hunter production frontend
- **bug-hunter-backend-1** - Bug Hunter FastAPI backend (internal)
- **bug-hunter-db-1** - PostgreSQL for Bug Hunter (internal)
- **bug-hunter-staging-frontend-1** (100.64.0.1:8507) - Bug Hunter staging frontend (Tailscale-only)
- **bug-hunter-staging-backend-1** - Bug Hunter staging backend (internal)
- **bug-hunter-staging-db-1** - PostgreSQL for Bug Hunter staging (internal)
- **compose-btcpay-1** (100.64.0.1:23000) - BTCPay Server UI (Tailscale-only) **[STOPPED 2026-05-24 — not in active use]**
- **compose-btcd-1** - Bitcoin full node (~500MB–1GB RAM) **[STOPPED]**
- **compose-nbxplorer-1** - NBXplorer blockchain indexer **[STOPPED]**
- **compose-btcpay-db-1** - PostgreSQL for BTCPay **[STOPPED]**

To restart BTCPay: `cd ~/vps-infrastructure/compose && docker compose -f docker-compose.btcpay.yml up -d`

### Support Services
- **logkeep-postgres** (127.0.0.1:5432) - PostgreSQL for LogKeep prod
- **bench-postgres** (5432) - PostgreSQL for Bench prod
- **bench-postgres-staging** (5432) - PostgreSQL for Bench staging
- **bench-redis** (6379) - Redis for Bench/Celery prod
- **bench-redis-staging** (6379) - Redis for Bench/Celery staging

### Exporters
- **monitoring-nginx-exporter** (9113) - Nginx metrics for Prometheus
- **logkeep-postgres-exporter** (9187) - PostgreSQL metrics
- **bench-postgres-exporter** (9188) - PostgreSQL metrics

### External Services
- **headplane** - Headscale UI (port 3001)
- **headscale** (systemd) - Tailscale control server (port 8090)
- **nginx** (systemd) - Reverse proxy with SSL termination (ports 80, 443)

## Networks

- **monitoring-network** - Monitoring stack (independent)
- **logkeep_logkeep-network** - LogKeep app stack (prod + staging)
- **bench_bench-network** - Bench app stack
- Prometheus scrapes targets on both monitoring-network and logkeep_logkeep-network

## Phase 3 Progress

✅ **Phase 3A: Monitoring Stack Separation** (Complete)
- Separated monitoring from application services
- Migrated 10.6GB historical data
- Independent monitoring-network
- All services healthy and operational

✅ **Phase 3B: Backup System** (Complete - documented, working)
- See `/srv/infra/docs/backup-improvements.md`
- Daily backups at 2 AM, 7-day retention, synced to pyrite
- Healthcheck cron at 3 AM

✅ **Phase 3C: Nginx Configuration** (Complete)
- Migrated from sites-enabled to conf.d structure
- Blue/green deploy via symlink at /etc/nginx/conf.d/logkeep.conf
- All SSL migrated to Let's Encrypt
- Security headers snippet shared across vhosts
- Version controlled in vps-infrastructure repo

✅ **Network Consolidation** (Complete)
- WireGuard decommissioned
- All remote connectivity via Tailscale
- nginx proxies updated to Tailscale IPs

✅ **Docker Project Cleanup** (Complete - 2026-04-20)
- Bench: reassigned from 'docker' to 'bench' project
- LogKeep-staging: reassigned to 'logkeep' project
- Container names updated to match proper project structure
- Stale monitoring services removed from logkeep compose
- Orphaned docker_logkeep-network cleaned up
- Three clean projects: infra (8), logkeep (6), bench (5)

🔲 **Phase 3D: Database Migration** (Next - requires user action)
- Create databases on pyrite (logkeep_prod, logkeep_staging, bench_prod, bench_staging)
- Migrate local PostgreSQL data
- Update app compose files to use remote DB
- Remove local postgres containers

🔲 **Phase 3E: Shared Services** (Future)
- Consider separating postgres to /srv/infra/
- Redis organization
- Shared database stack

## Next Steps

1. **LogKeep major update** — containers stopped pending rewrite. When redeploying:
   - Tune gunicorn worker count in `docker-compose.prod.yml` (current default spawns ~10 workers × ~135 MB = ~1.4 GB). Set `--workers` to 2–3 to cap at ~400 MB.
   - Fix LLM API key in `.env` (logkeep has been sending 401s to model-gateway since the model-gateway migration; retry storm was generating `HighRequestRateSpike` alerts continuously)
2. **Database Migration to Pyrite** - Create databases, migrate data, update compose files
3. **Remove Local PostgreSQL** - After migration validated
4. **Pyrite PostgreSQL Monitoring** - Add scrape job for postgres_exporter on pyrite
5. **Network Simplification** - Clean up unused Docker networks
6. **Application Organization** - Consider moving to /srv/apps/
