# VPS Infrastructure Reorganization - Implementation Guide

**Created:** April 7, 2026  
**Last Updated:** April 20, 2026  
**Status:** Phase 3C complete, Phase 3D (database migration) pending

---

## Pre-Implementation Summary

### Confirmed Details

**Infrastructure:**
- VPS: gatekeeper (74.208.107.78), Ubuntu, 19 containers
- Remote: pyrite (100.64.0.2), Ubuntu 24.04, Tailscale peer
- Services: Dev/testing only, downtime acceptable
- No existing backups (code on GitHub only)

**Current State:**
- LogKeep: `/opt/logkeep/docker/` - has blue (8001), green (8002), staging (8003)
  - DB: `logkeep-postgres` (local container) with databases: `logkeep`, `logkeep_staging`
  - User: `logkeep_admin`
- Bench: `/opt/bench/docker/` - single deployment (8010, under 'bench' project)
   - DB: `bench-postgres` (local container) with database: `bench`
  - User: `bench`
  - No staging environment yet

**Pyrite (100.64.0.2):**
- PostgreSQL 16 in container
- llama.cpp as systemd service
- postgres_exporter container running
- Large RAID array with SSD cache
- Always-on
- SSH: Port 4444 (non-standard)

**Decisions:**
- New GitHub repo: `vps-infrastructure`
- DNS: Manual via Ionos dashboard (user will create records when ready)
- Ionos wildcard cert: User will research details later
- Phase 4 (Polish): Optional
- Timeline: Natural pace, pause after Phase 1

---

## ✅ PHASE 3C COMPLETION SUMMARY (April 20, 2026)

### Docker Project Cleanup

The stale 'docker' compose project has been eliminated. All containers now use proper project names:

| Project | Containers | Files |
|---------|-----------|-------|
| **bench** | 5 | `/opt/bench/docker/docker-compose.prod.yml` |
| **logkeep** | 6 | `/opt/logkeep/docker/docker-compose.{prod,staging}.yml` |
| **infra** | 8 | `/srv/infra/docker-compose.monitoring.yml` |

#### Changes Made

1. **Bench Project Rename**
   - Moved containers from 'docker' to 'bench' project: `docker-bench-*` → explicit `bench-*` names
   - Modified compose file to use external volume `docker_bench-postgres-data` to preserve data
   - All 5 containers (web, postgres, redis, celery, celery-beat) now running under 'bench' project

2. **LogKeep Project Consolidation**
   - Moved staging container from 'docker' to 'logkeep' project
   - Staging compose now part of unified logkeep project with production
   - Removed 8 stale monitoring services from logkeep-docker-compose.prod.yml
   - Removed obsolete `version` keys from compose files

3. **Network Cleanup**
   - Orphaned `docker_logkeep-network` removed
   - Clean network structure: `bench_bench-network`, `logkeep_logkeep-network`, `monitoring-network`
   - Prometheus scrapes targets on monitoring-network and logkeep_logkeep-network

4. **Nginx & Configuration Sync**
   - model.conf: Comments updated (WireGuard → Tailscale)
   - logkeep.conf: Removed OCSP stapling block to match live
   - All configs synced to repo

5. **Git Commit**
   - All changes committed: `f52f7ef - Sync repo with live infrastructure`
   - 11 files updated, 277 insertions, 351 deletions

---

**IMPORTANT:** User will create these after Phase 3 Services 1, 3, 8 are complete (before Services 2, 5, 6, 7).

### Databases to Create

```sql
-- LogKeep databases
CREATE DATABASE logkeep_prod;
CREATE DATABASE logkeep_staging;

-- Bench databases
CREATE DATABASE bench_prod;
CREATE DATABASE bench_staging;  -- New, start empty
```

### Users to Create

```sql
-- LogKeep user
CREATE USER logkeep_user WITH PASSWORD '<secure_password>';
GRANT ALL PRIVILEGES ON DATABASE logkeep_prod TO logkeep_user;
GRANT ALL PRIVILEGES ON DATABASE logkeep_staging TO logkeep_user;

-- In each logkeep database, grant schema permissions:
\c logkeep_prod
GRANT ALL PRIVILEGES ON SCHEMA public TO logkeep_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO logkeep_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO logkeep_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO logkeep_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO logkeep_user;

\c logkeep_staging
GRANT ALL PRIVILEGES ON SCHEMA public TO logkeep_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO logkeep_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO logkeep_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO logkeep_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO logkeep_user;

-- Bench user
CREATE USER bench_user WITH PASSWORD '<secure_password>';
GRANT ALL PRIVILEGES ON DATABASE bench_prod TO bench_user;
GRANT ALL PRIVILEGES ON DATABASE bench_staging TO bench_user;

-- In each bench database, grant schema permissions:
\c bench_prod
GRANT ALL PRIVILEGES ON SCHEMA public TO bench_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO bench_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO bench_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO bench_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO bench_user;

\c bench_staging
GRANT ALL PRIVILEGES ON SCHEMA public TO bench_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO bench_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO bench_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO bench_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO bench_user;
```

### Connection Strings Format

After database creation, user should provide these connection strings:

```bash
# LogKeep Production
LOGKEEP_PROD_DB=postgresql://logkeep_user:<password>@100.64.0.2:5432/logkeep_prod

# LogKeep Staging
LOGKEEP_STAGING_DB=postgresql://logkeep_user:<password>@100.64.0.2:5432/logkeep_staging

# Bench Production
BENCH_PROD_DB=postgresql://bench_user:<password>@100.64.0.2:5432/bench_prod

# Bench Staging
BENCH_STAGING_DB=postgresql://bench_user:<password>@100.64.0.2:5432/bench_staging
```

---

## REVISED EXECUTION ORDER

### Prerequisites

**SSH Key Setup for Remote Backups:**

Remote backups to pyrite work automatically using your user's SSH keys (no sudo required).

**Setup verification:**
```bash
# Test backup script (runs as your user, not root)
/srv/backups/backup-databases.sh

# Verify remote backups
ssh pyrite "ls -lh /mnt/storage/backups/vps/"
```

**Note:** 
- Backup script runs as `siderealyear` user (docker group membership allows container access)
- `/srv/backups` and `/var/log/vps-backup.log` owned by `siderealyear`
- SSH to pyrite uses your `~/.ssh/config` settings (hostname: pyrite, port: 4444)

**Daily Backup Schedule: Configured**

Cron job configured in user crontab (siderealyear, not root):
```bash
# Daily backups at 2 AM
0 2 * * * /srv/backups/backup-databases.sh
```

To view or edit:
```bash
crontab -l  # View current crontab
crontab -e  # Edit crontab
```

---

### Phase 1: Quick Wins (Week 1, 8-12 hours) READY TO START

**No changes from original plan.** All tasks can proceed immediately:

- [x] 1.1 - Clean up unused Docker networks
- [x] 1.2 - Remove unused UFW rules
- [x] 1.3 - Fix logkeep-staging health check (Python urllib instead of curl)
- [x] 1.4 - Add SSL certificate monitoring (Blackbox Exporter on port 9115)
- [x] 1.5 - Add container health alerts (4 rules: unhealthy, restarting, memory, CPU)
- [x] 1.6 - Add disk usage alerts (verified existing rules)
- [x] 1.7 - Document SSH reverse tunnel (deprecated - already done)
- [x] 1.8 - Create initial backup script (runs as siderealyear, syncs to pyrite)
- [x] 1.9 - Test backup restoration (verified bench database restore)

**Pause Point:** Evaluate results, decide whether to continue to Phase 2.

---

### Phase 2: Foundation (Week 2-3, 14-18 hours)

**No changes from original plan:**

- [x] 2.1 - Create `vps-infrastructure` GitHub repository
- [x] 2.2 - Set up repository structure
- [x] 2.3 - Export current docker-compose files
- [ ] 2.4 - Create `docker-compose.core.yml`
- [ ] 2.5 - Externalize secrets to `.env` template
- [x] 2.6 - Export nginx configs
- [x] 2.7 - Export Prometheus/Grafana configs
- [x] 2.8 - Create deployment script
- [x] 2.9 - Create health check script
- [ ] 2.10 - Create documentation generation script
- [x] 2.11 - Write documentation
- [x] 2.12 - Verify Ionos wildcard certificate (user will research)
- [x] 2.13 - Plan Let's Encrypt to Ionos migration (deferred)
- [x] 2.14 - Create `/srv/infra/` directory structure

---

### Phase 3: Migration (Week 3-4, 26-38 hours) REVISED ORDER

**CRITICAL CHANGE:** Database consolidation moved to AFTER network consolidation.

#### Part A: Infrastructure Migration (No database dependencies)

**Service 1: Monitoring Stack Separation (3-4 hours)** ✅ COMPLETE
- [x] 3.1 - Export Grafana dashboards
- [x] 3.2 - Create `docker-compose.monitoring.yml` (rename containers: `monitoring-*`)
- [x] 3.3 - Stop current `logkeep-*` monitoring containers
- [x] 3.4 - Move volumes to `/srv/infra/data/monitoring/`
- [x] 3.5 - Start new independent monitoring stack
- [x] 3.6 - Validate Grafana access, check datasources
- [x] 3.7 - Verify Prometheus scraping all targets
- [x] 3.8 - Test alert rules and Alertmanager
- [x] 3.9 - Confirm monitoring independence
- **Downtime:** 5 min (acceptable)

**Service 3: Public Access Strategy (1 hour)** ✅ COMPLETE
- [x] 3.19 - Update nginx TCP stream for PostgreSQL (db.perdrizet.org:54321 → 100.64.0.2:5432)
- [x] 3.20 - Rename gpt.conf → llm.conf, update domain (llm.perdrizet.org → 100.64.0.2:8502)
- [x] 3.21 - Add DNS A records (user action: db.perdrizet.org, llm.perdrizet.org)
- [x] 3.22 - Test nginx config: `nginx -t`
- [x] 3.23 - Reload nginx: `nginx -s reload`
- [x] 3.24 - Test PostgreSQL access from external machine
- [x] 3.25 - Test llama.cpp access: `curl -I https://llm.perdrizet.org`
- [x] 3.26 - Update documentation
- [x] 3.27 - Update services.md
- [x] 3.28 - Remove unused SSH reverse tunnel (no action needed - nothing listening)
- **Downtime:** <1 min

**Service 4: Headplane - SKIP** Already working, user said don't touch it

**Service 8: Network Consolidation (1 hour)** ✅ COMPLETE
- [x] 3.59 - Verify Tailscale peer identity: `tailscale status`
- [x] 3.60 - Test PostgreSQL via Tailscale: `nc -zv 100.64.0.2 5432`
- [x] 3.61 - Test llama.cpp via Tailscale: `curl -I http://100.64.0.2:8502`
- [x] 3.62 - Verify nginx already using Tailscale IPs (from Service 3)
- [x] 3.63 - Monitor for 1 hour - no connectivity issues
- [x] 3.64 - Tear down WireGuard: `wg-quick down wg0; systemctl disable wg-quick@wg0`
- [x] 3.65 - Remove UFW rule for port 51820
- [x] 3.66 - Archive WireGuard config (backup)
- [x] 3.67 - Update documentation
- **Downtime:** 2-3 min

**🛑 PAUSE POINT - User Action Required:**
1. Create databases on pyrite (see "DATABASE REQUIREMENTS" above)
2. Create users (logkeep_user, bench_user)
3. Provide connection strings to continue

---

#### Part B: Database & Application Migration (Requires pyrite databases ready)

**Service 2: Database Setup Verification (30 min)**
- [ ] 3.10 - Test connection to pyrite PostgreSQL: `psql -h 100.64.0.2 -p 5432 -U logkeep_user -d logkeep_prod`
- [ ] 3.11 - Verify all 4 databases exist and users have correct permissions
- [ ] 3.12 - Export bench database: `docker exec bench-postgres pg_dump -U bench bench > bench-export.sql`
- [ ] 3.13 - Import to pyrite: `psql -h 100.64.0.2 -U bench_user -d bench_prod < bench-export.sql`
- [ ] 3.14 - Export logkeep production: `docker exec logkeep-postgres pg_dump -U logkeep_admin logkeep > logkeep-prod-export.sql`
- [ ] 3.15 - Export logkeep staging: `docker exec logkeep-postgres pg_dump -U logkeep_admin logkeep_staging > logkeep-staging-export.sql`
- [ ] 3.16 - Import to pyrite
- [ ] 3.17 - Test connectivity and query counts
- [ ] 3.18 - Update `.env` with remote connection strings (user provides)

**Service 5: Bench Stack Migration (3-4 hours)**
- [ ] 3.32 - Create `docker-compose.bench.yml` (blue, green, staging, remote DB, no local postgres)
- [ ] 3.33 - Stop old bench containers
- [ ] 3.34 - Start new bench stack
- [ ] 3.35 - Validate bench-blue connects to remote DB
- [ ] 3.36 - Create nginx vhost for bench-staging.perdrizet.org
- [ ] 3.37 - Update bench.perdrizet.org → bench-blue (port 8012)
- [ ] 3.38 - Validate production: https://bench.perdrizet.org
- [ ] 3.39 - Validate staging: https://bench-staging.perdrizet.org
- [ ] 3.40 - Test bench-green
- [ ] 3.41 - Keep old bench-postgres container for 1 week
- [ ] 3.42 - Document blue-green procedure
- **Downtime:** 5-10 min
- **Containers eliminated:** -1 (later)

**Service 6: LogKeep Staging (1 hour)**
- [ ] 3.43 - Stop staging
- [ ] 3.44 - Fix health check (from Phase 1)
- [ ] 3.45 - Update compose - use remote DB
- [ ] 3.46 - Start via new compose
- [ ] 3.47 - Validate staging access and DB connection
- **Downtime:** 2 min

**Service 7: LogKeep Production (4-6 hours)**
- [ ] 3.48 - Update `docker-compose.logkeep.yml` (blue, green use remote DB, no local postgres)
- [ ] 3.49 - Deploy new blue
- [ ] 3.50 - Validate DB connection
- [ ] 3.51 - Update nginx → new blue
- [ ] 3.52 - Reload nginx
- [ ] 3.53 - Validate production traffic
- [ ] 3.54 - Stop old containers
- [ ] 3.55 - Deploy new green
- [ ] 3.56 - Update compose final ports
- [ ] 3.57 - Reconfigure nginx
- [ ] 3.58 - Keep old postgres for 1 week
- **Downtime:** 0 (blue/green)
- **Containers eliminated:** -1 (later)

**Service 9: PostgreSQL Monitoring (2 hours)**
- [ ] 3.68 - Verify exporter on pyrite: `curl http://100.64.0.2:9187/metrics`
- [ ] 3.69 - Add scrape job to Prometheus
- [ ] 3.70 - Reload Prometheus
- [ ] 3.71 - Validate scraping in Grafana
- [ ] 3.72 - Create Grafana dashboard for pyrite PostgreSQL
- [ ] 3.73 - Add alert rules
- [ ] 3.74 - Test alerts
- [ ] 3.75 - Document unified monitoring
- **Downtime:** None

**Post-Migration Validation (2-3 hours)**
- [ ] 3.76 - Verify all services in new locations
- [ ] 3.77 - Run health check: `./scripts/health-check.sh`
- [ ] 3.78 - Verify monitoring (including pyrite)
- [ ] 3.79 - Test all public endpoints
- [ ] 3.80 - Test bench blue-green swap
- [ ] 3.81 - Test logkeep blue-green swap
- [ ] 3.82 - Generate updated docs
- [ ] 3.83 - Monitor for 24-48 hours
- [ ] 3.84 - Verify remote PostgreSQL load handling
- [ ] 3.85 - Remove old `/opt/` directories (wait 1 week)
- [ ] 3.86 - Remove WireGuard backup (wait 1 week)
- [ ] 3.87 - Remove old PostgreSQL containers and volumes (wait 1 week)

---

### Phase 4: Polish (Optional, Week 5-6, 6-10 hours)

**Deferred - can be added later if desired:**
- Ionos certificate expiry monitoring
- Public Grafana/Headplane access
- Tailscale peer health monitoring
- Additional Grafana dashboards
- Automated documentation updates
- Disaster recovery drill
- Performance tuning
- Runbooks creation

---

## CURRENT STATUS

**Phases 1-2:** Complete  
**Phase 3 Part A:** Complete (Services 1, 3, 8)  
**Next Action:** User creates databases on pyrite, then begin Phase 3 Part B

**Critical Path:**
1. ~~Phase 1 → evaluate → Phase 2 → Phase 3 Part A~~ ✅ Done
2. **PAUSE (current):** User creates pyrite databases
3. Phase 3 Part B → completion

**Total Estimated Time:**
- Phase 1: 8-12 hours
- Phase 2: 14-18 hours  
- Phase 3 Part A: 5-6 hours
- **USER ACTION: Database creation**
- Phase 3 Part B: 10-14 hours
- Phase 3 Validation: 2-3 hours
- **Total: 39-53 hours**

**Container Reduction:** 19 → 17 containers (-2 PostgreSQL after validation period)

---

## NOTES

1. **No monitoring gaps matter** - services are dev/testing only
2. **Downtime acceptable** - not supporting real users
3. **No rush** - proceed at natural pace
4. **Headplane** - working correctly, excluded from migration
5. **DNS records** - user will create manually when services are ready to go public
6. **Ionos cert** - user researching, not blocking
7. **Backups** - new script will backup to pyrite
8. **VPS-local PostgreSQL** - keep running for 1 week after migration for safety

