# VPS Infrastructure

Infrastructure as code for VPS services, monitoring, and configuration management.

## Repository structure

```
vps-infrastructure/
├── compose/                    # Docker Compose files
│   ├── logkeep-docker-compose.yml       # LogKeep base config
│   ├── logkeep-docker-compose.prod.yml  # LogKeep production
│   ├── logkeep-docker-compose.staging.yml  # LogKeep staging
│   ├── bench-docker-compose.yml         # Bench base config
│   └── bench-docker-compose.prod.yml    # Bench production
├── configs/                    # Service configurations
│   ├── nginx/                  # Nginx site configs and snippets
│   └── monitoring/             # Prometheus, Grafana, Loki configs
├── scripts/                    # Automation scripts
│   ├── deploy.sh              # Deployment automation
│   └── health-check.sh        # Service health verification
├── docs/                       # Documentation
├── docker-compose.monitoring.yml  # Monitoring stack compose
└── README.md                  # This file
```

## Quick start

### 1. Clone repository

```bash
git clone git@github.com:gperdrizet/vps-infrastructure.git
cd vps-infrastructure
```

### 2. Configure environment

```bash
# Copy template and fill in your secrets
cp .env.template .env
nano .env
```

### 3. Deploy services

```bash
# Deploy all services
./scripts/deploy.sh

# Or deploy specific services
./scripts/deploy.sh logkeep
./scripts/deploy.sh bench
./scripts/deploy.sh monitoring
```

### 4. Verify health

```bash
./scripts/health-check.sh
```

## Services overview

### Applications

- **LogKeep** (`/opt/logkeep/docker/`)
  - Production: Port 8001-8002 (blue/green deployment)
  - Staging: Port 8003
  - Database: PostgreSQL (local container → migrating to pyrite)

- **Bench** (`/opt/bench/docker/`)
  - Production: Port 8010
  - Database: PostgreSQL (local container → migrating to pyrite)

### Infrastructure

- **Monitoring Stack**
  - Prometheus: :9090 (metrics collection)
  - Grafana: :3000 (dashboards)
  - Loki: :3100 (log aggregation)
  - Alertmanager: :9093 (alert routing)
  - Blackbox Exporter: :9115 (SSL/endpoint monitoring)

- **Nginx** (Reverse Proxy)
  - logkeep.perdrizet.org → :8001 (blue) / :8002 (green)
  - bench.perdrizet.org → :8010
  - staging.perdrizet.org → :8003
  - model.perdrizet.org → pyrite:8502 (via Tailscale)
  - headscale.perdrizet.org → :8090
  - headplane.perdrizet.org → :3001
  - grafana.perdrizet.org → :3000
  - perdrizet.org → redirect to logkeep
  - db.perdrizet.org:54321 → pyrite:5432 (TCP stream)

### Remote services (Pyrite @ 100.64.0.2)

- PostgreSQL 16 (containerized)
- llama.cpp (systemd service on :8502)
- postgres_exporter (metrics)
- RAID array with SSD cache

## Security

- **Never commit `.env` file** - it contains secrets
- Secrets are externalized via environment variables
- Database passwords are generated securely
- SSH keys used for automated backups

## Backups

Automated daily backups to pyrite:

```bash
# Manual backup
/srv/backups/backup-databases.sh

# Verify remote backups
ssh pyrite "ls -lh /mnt/storage/backups/vps/"

# Cron schedule (2 AM daily)
0 2 * * * /srv/backups/backup-databases.sh
```

## Migration status

### Phase 1: Quick wins ✅ Complete
- Docker network cleanup
- UFW rules cleanup
- Health check fixes
- SSL certificate monitoring (Blackbox Exporter)
- Container health alerts
- Backup system (local + remote to pyrite)

### Phase 2: Foundation ✅ Complete
- Version control setup (this repository)
- Configuration export
- Deployment automation

### Phase 3A: Monitoring Separation ✅ Complete
- Independent monitoring stack at /srv/infra/
- 10.6GB historical data migrated
- monitoring-network isolated from apps

### Phase 3B-C: Backups + Nginx ✅ Complete
- Daily backups working, synced to pyrite
- Nginx migrated to conf.d, all SSL on Let's Encrypt
- Blue/green deploy for LogKeep via symlink

### Network Consolidation ✅ Complete
- WireGuard decommissioned
- All remote connectivity via Tailscale

### Phase 3D: Database Migration ⏳ Next
- Migrate PostgreSQL to pyrite
- Remove local database containers

## Monitoring

### Prometheus targets

- cAdvisor: Container metrics
- Node Exporter: System metrics
- Blackbox Exporter: SSL certificate monitoring
- Postgres Exporter: Database metrics (pyrite)

### SSL certificates monitored

- bench.perdrizet.org
- staging.perdrizet.org
- headscale.perdrizet.org
- logkeep.perdrizet.org
- model.perdrizet.org
- grafana.perdrizet.org
- headplane.perdrizet.org

### Alerts configured

- SSL certificate expiration (30/7 day warnings)
- Container health (unhealthy, restarting, high memory, CPU throttling)
- Disk space (warning <20%, critical <10%)

## Maintenance

### Update Docker images

```bash
cd /opt/logkeep/docker
docker compose pull
docker compose up -d

cd /opt/bench/docker
docker compose pull
docker compose up -d
```

### View logs

```bash
# All containers
docker ps

# Specific service
docker logs -f logkeep-app

# Monitoring logs
docker logs -f logkeep-prometheus
docker logs -f logkeep-grafana
```

### Restart services

```bash
# LogKeep
cd /opt/logkeep/docker && docker compose restart

# Bench  
cd /opt/bench/docker && docker compose restart

# Nginx
sudo systemctl restart nginx
```

## Documentation

- [Implementation Guide](./docs/IMPLEMENTATION-GUIDE.md) - Detailed migration plan
- [Services Overview](./docs/services.md) - Current service inventory

## Resources

- **VPS**: gatekeeper (74.208.107.78)
- **Remote**: pyrite (100.64.0.2 via Tailscale)
- **GitHub**: https://github.com/gperdrizet/vps-infrastructure
- **DNS**: Managed via Ionos dashboard

## Tips

- Always test nginx config after changes: `sudo nginx -t`
- Check container health: `docker ps --format "table {{.Names}}\t{{.Status}}"`
- Monitor disk space: `df -h /`
- Check backup logs: `tail -f /var/log/vps-backup.log`

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs <container-name>

# Check compose file syntax
docker compose config

# Recreate container
docker compose up -d --force-recreate <service-name>
```

### Database connection issues

```bash
# Test local postgres
docker exec logkeep-postgres psql -U logkeep_admin -d logkeep -c "SELECT version();"

# Test pyrite postgres
psql -h 100.64.0.2 -p 5432 -U logkeep_user -d logkeep_prod
```

### Monitoring not collecting metrics

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Reload Prometheus config
docker exec logkeep-prometheus kill -HUP 1
```

## License

Private repository - internal infrastructure documentation.

---

**Last Updated**: April 8, 2026  
**Maintainer**: George Perdrizet <george@perdrizet.org>
