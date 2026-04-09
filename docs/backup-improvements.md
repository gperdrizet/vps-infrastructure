# Backup System Improvements (Phase 3 - Deferred)

## Current State

- **Schedule**: Daily at 2 AM via cron (`0 2 * * * /srv/backups/backup-databases.sh`)
- **Databases**: 
  - `logkeep` (production) - 26KB compressed
  - `logkeep_staging` - 3.4KB compressed
  - `bench` - 16KB compressed
- **Storage**:
  - Local: `/srv/backups/` (7-day retention)
  - Remote: `pyrite:/mnt/storage/backups/vps` via Tailscale (100.64.0.2:4444)
- **Logs**: `/var/log/vps-backup.log`
- **User**: `siderealyear` (docker group)

## Proposed Improvements

### 1. Consolidate to /srv/infra/
- Move scripts from `/srv/backups/` to `/srv/infra/scripts/`
- Keep backup data in `/srv/backups/` (separate from code)
- Update crontab to use new location

### 2. Monitoring Integration
- Export backup metrics to Prometheus:
  - `backup_last_success_timestamp` - Unix timestamp of last successful backup
  - `backup_file_size_bytes` - Size of last backup per database
  - `backup_duration_seconds` - How long backup took
  - `backup_failures_total` - Counter of failed backups
- Create Prometheus alert rules:
  - `BackupNotRun` - No backup in 26 hours (daily + 2hr grace)
  - `BackupFailed` - Backup script exited with error
  - `BackupTooSmall` - Backup file smaller than expected (potential corruption)
  - `RemoteSyncFailed` - Failed to sync to pyrite
- Add to existing Alertmanager email notifications

### 3. Health Check Script
Create `/srv/infra/scripts/backup-healthcheck.sh`:
- Verify backup files exist and are recent
- Check backup file integrity (gzip test)
- Test database connectivity
- Verify remote sync status
- Export metrics to textfile for node_exporter

### 4. Restore Documentation
Create `/srv/infra/docs/backup-restore.md`:
- Step-by-step restore procedures
- Database restore commands
- Point-in-time recovery options
- Disaster recovery runbook
- Required credentials and access

### 5. Automated Restore Testing
- Monthly automated restore test to temporary container
- Verify data integrity after restore
- Alert if test restore fails
- Document last successful test in metrics

### 6. Backup Rotation Improvements
Current: Simple 7-day retention with find + mtime
Proposed:
- Keep daily backups for 7 days
- Keep weekly backups (Sunday) for 4 weeks
- Keep monthly backups (1st) for 6 months
- Grandfather-father-son rotation strategy

### 7. Additional Databases
Monitor for new databases automatically:
- Auto-discover postgres containers
- Auto-configure backup for new DBs
- Alert when new database detected without backup

## Implementation Priority

**High Priority** (Security & Reliability):
1. Monitoring integration (alerts for backup failures)
2. Restore documentation
3. Health check script

**Medium Priority** (Operational Excellence):
4. Move to /srv/infra/
5. Automated restore testing
6. Improved rotation strategy

**Low Priority** (Nice to Have):
7. Auto-discovery of new databases

## Dependencies

- Prometheus/Alertmanager already configured
- Node exporter textfile collector enabled
- SSH access to pyrite (100.64.0.2:4444)
- rsync installed

## Estimated Effort

- Monitoring integration: 2-3 hours
- Documentation: 1-2 hours
- Health checks: 1 hour
- Restore testing: 2-3 hours
- Total: ~8 hours

## Deferred Reason

Backup system is currently working reliably. These improvements enhance monitoring and testing but are not critical for infrastructure separation goals. Will implement after Phase 3 core separations are complete.
