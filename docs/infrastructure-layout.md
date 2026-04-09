# VPS Infrastructure Layout

## Overview
Current VPS organization after Phase 1-3A (Monitoring Separation Complete)

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
│   │   ├── docker-compose.yml
│   │   ├── docker-compose.prod.yml
│   │   ├── docker-compose.staging.yml
│   │   ├── .env.production
│   │   └── .env.staging
│   ├── monitoring/          # OLD monitoring configs (can be removed)
│   ├── nginx/               # Nginx configs for app
│   └── scripts/             # App management scripts
│
└── bench/                   # Bench application
    ├── src/                 # Application code
    └── docker/              # Docker compose files
        ├── docker-compose.yml
        ├── docker-compose.prod.yml
        └── nginx/

/etc/nginx/
├── sites-available/
│   ├── bench.perdrizet.org      # Bench app (-> 127.0.0.1:8010)
│   ├── staging.conf             # LogKeep staging
│   ├── gpt.conf                 # GPT service
│   └── headscale                # Headscale VPN
└── sites-enabled/               # Symlinks to active sites

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
- **monitoring-blackbox-exporter** (9115) - SSL cert monitoring

### Applications
- **logkeep-blue** (8001) - LogKeep production (blue slot)
- **logkeep-green** (8002) - LogKeep production (green slot)
- **logkeep-staging** (8000) - LogKeep staging environment
- **docker-bench-web-1** (8010) - Bench web application
- **docker-bench-celery-1** - Bench background tasks
- **docker-bench-celery-beat-1** - Bench scheduled tasks

### Support Services
- **logkeep-postgres** (5432) - PostgreSQL for LogKeep
- **docker-bench-postgres-1** - PostgreSQL for Bench
- **docker-bench-redis-1** - Redis for Bench/Celery

### Exporters
- **logkeep-nginx-exporter** (9113) - Nginx metrics for Prometheus
- **logkeep-postgres-exporter** (9187) - PostgreSQL metrics

### External Services
- **headplane** - Headscale UI (port 3001)
- **nginx** (systemd) - Reverse proxy with SSL termination (ports 80, 443)

## Networks

- **monitoring-network** - Independent monitoring stack
- **logkeep_logkeep-network** - LogKeep app network
- **docker_default** - Bench app network
- Prometheus connects to both monitoring-network and logkeep_logkeep-network for scraping

## Phase 3 Progress

✅ **Phase 3A: Monitoring Stack Separation** (Complete)
- Separated monitoring from application services
- Migrated 10.6GB historical data
- Independent monitoring-network
- All services healthy and operational

⏳ **Phase 3B: Backup System** (Documented, Deferred)
- See `/srv/infra/docs/backup-improvements.md`
- Working reliably, enhancements planned for later

🔲 **Phase 3C: Nginx Configuration** (Next)
- Centralize nginx configs to /srv/infra/configs/nginx/
- Version control all site configs
- Document SSL certificate management

🔲 **Phase 3D: Shared Services** (Future)
- Consider separating postgres to /srv/infra/
- Redis organization
- Shared database stack

## Next Steps

1. **Centralize Nginx Configs** - Move from /etc/nginx/ to /srv/infra/configs/nginx/
2. **Document SSL Management** - Let's Encrypt renewal process
3. **Application Organization** - Consider moving to /srv/apps/
4. **Network Simplification** - Reduce number of Docker networks
5. **Commit to Git** - Update vps-infrastructure repo with all changes
