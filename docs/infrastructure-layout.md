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
└── bench/                   # Bench application
    ├── src/                 # Application code
    └── docker/              # Docker compose files
        ├── docker-compose.yml          # Development
        ├── docker-compose.prod.yml     # Production (active)
        └── .env.production

/etc/nginx/
├── conf.d/
│   ├── bench.conf               # Bench app (-> 127.0.0.1:8010)
│   ├── grafana.conf             # Grafana (-> 127.0.0.1:3000)
│   ├── headplane.conf           # Headplane (-> 127.0.0.1:3001)
│   ├── headscale.conf           # Headscale (-> 127.0.0.1:8090)
│   ├── logkeep.conf             # Symlink -> /etc/nginx/logkeep-configs/blue.conf
│   ├── model.conf               # LLM proxy (-> 100.64.0.2:8502)
│   ├── perdrizet.conf           # Root domain redirect
│   └── staging.conf             # LogKeep staging (-> 127.0.0.1:8003)
├── logkeep-configs/
│   ├── blue.conf                # LogKeep blue (-> 127.0.0.1:8001)
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
- **logkeep-blue** (8001) - LogKeep production (blue slot)
- **logkeep-green** (8002) - LogKeep production (green slot, started on deploy)
- **logkeep-staging** (8003) - LogKeep staging environment
- **bench-bench-web-1** (8010) - Bench web application
- **bench-bench-celery-1** - Bench background tasks
- **bench-bench-celery-beat-1** - Bench scheduled tasks

### Support Services
- **logkeep-postgres** (5432) - PostgreSQL for LogKeep
- **bench-bench-postgres-1** (5432) - PostgreSQL for Bench
- **bench-bench-redis-1** (6379) - Redis for Bench/Celery

### Exporters
- **logkeep-nginx-exporter** (9113) - Nginx metrics for Prometheus
- **logkeep-postgres-exporter** (9187) - PostgreSQL metrics

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

1. **Database Migration to Pyrite** - Create databases, migrate data, update compose files
2. **Remove Local PostgreSQL** - After migration validated
3. **Pyrite PostgreSQL Monitoring** - Add scrape job for postgres_exporter on pyrite
4. **Network Simplification** - Clean up unused Docker networks
5. **Application Organization** - Consider moving to /srv/apps/
