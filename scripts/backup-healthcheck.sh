#!/bin/bash
#
# Backup Health Check Script
# Verifies database backups are running correctly
# Exports metrics for Prometheus node_exporter textfile collector
#
# Location: /srv/infra/scripts/backup-healthcheck.sh
# Schedule: Run after backups (cron: 0 3 * * *)
#

set -euo pipefail

# Configuration
BACKUP_DIR="/srv/backups"
METRICS_DIR="/var/lib/node_exporter/textfile_collector"
METRICS_FILE="$METRICS_DIR/backup_status.prom"
MAX_AGE_HOURS=26  # Daily backup + 2hr grace period

# Create metrics directory if needed
sudo mkdir -p "$METRICS_DIR" 2>/dev/null || true

# Temporary metrics file
TEMP_METRICS=$(mktemp)

# Cleanup on exit
trap "rm -f $TEMP_METRICS" EXIT

# Header for metrics file
cat > "$TEMP_METRICS" << 'EOF'
# HELP backup_last_success_timestamp Unix timestamp of last successful backup
# TYPE backup_last_success_timestamp gauge
# HELP backup_file_size_bytes Size of most recent backup file
# TYPE backup_file_size_bytes gauge
# HELP backup_age_seconds Age of most recent backup in seconds
# TYPE backup_age_seconds gauge
# HELP backup_status Status of backup (1=healthy, 0=missing/old)
# TYPE backup_status gauge
EOF

# Function to check backup for a database
check_backup() {
    local db_name=$1
    local backup_pattern="${BACKUP_DIR}/${db_name}_*.sql.gz"
    
    # Find most recent backup
    local latest_backup=$(ls -t $backup_pattern 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        echo "backup_status{database=\"$db_name\"} 0" >> "$TEMP_METRICS"
        echo "# No backup found for $db_name" >> "$TEMP_METRICS"
        echo "⚠  WARNING: No backup found for $db_name" >&2
        return 1
    fi
    
    # Get backup timestamp and size
    local backup_time=$(stat -c %Y "$latest_backup")
    local backup_size=$(stat -c %s "$latest_backup")
    local current_time=$(date +%s)
    local age_seconds=$((current_time - backup_time))
    local age_hours=$((age_seconds / 3600))
    
    # Check if backup is too old
    if [ $age_hours -gt $MAX_AGE_HOURS ]; then
        echo "backup_status{database=\"$db_name\"} 0" >> "$TEMP_METRICS"
        echo "⚠  WARNING: Backup for $db_name is $age_hours hours old (max: $MAX_AGE_HOURS)" >&2
        status=0
    else
        echo "backup_status{database=\"$db_name\"} 1" >> "$TEMP_METRICS"
        echo "✓ Backup for $db_name is fresh ($age_hours hours old)" >&2
        status=1
    fi
    
    # Export metrics
    echo "backup_last_success_timestamp{database=\"$db_name\"} $backup_time" >> "$TEMP_METRICS"
    echo "backup_file_size_bytes{database=\"$db_name\"} $backup_size" >> "$TEMP_METRICS"
    echo "backup_age_seconds{database=\"$db_name\"} $age_seconds" >> "$TEMP_METRICS"
    
    # Verify backup integrity (gzip test)
    if gunzip -t "$latest_backup" 2>/dev/null; then
        echo "backup_integrity{database=\"$db_name\"} 1" >> "$TEMP_METRICS"
        echo "  ✓ Backup integrity verified" >&2
    else
        echo "backup_integrity{database=\"$db_name\"} 0" >> "$TEMP_METRICS"
        echo "  ✗ CRITICAL: Backup file is corrupted!" >&2
        status=0
    fi
    
    return $status
}

# Check all databases
echo "=== Backup Health Check: $(date) ===" >&2

overall_status=1

check_backup "logkeep" || overall_status=0
check_backup "logkeep_staging" || overall_status=0
check_backup "bench" || overall_status=0

# Check remote sync status (if pyrite is reachable)
if ssh -p 4444 -o ConnectTimeout=5 root@100.64.0.2 "test -f /mnt/storage/backups/vps/logkeep_*.sql.gz" 2>/dev/null; then
    echo "backup_remote_sync{destination=\"pyrite\"} 1" >> "$TEMP_METRICS"
    echo "✓ Remote sync to pyrite is working" >&2
else
    echo "backup_remote_sync{destination=\"pyrite\"} 0" >> "$TEMP_METRICS"
    echo "⚠  WARNING: Cannot verify remote sync to pyrite" >&2
fi

# Write metrics file atomically
sudo mv "$TEMP_METRICS" "$METRICS_FILE" 2>/dev/null || {
    # If can't write to /var/lib, try /tmp for now
    mv "$TEMP_METRICS" "/tmp/backup_status.prom"
    echo "⚠  WARNING: Could not write to $METRICS_FILE, wrote to /tmp/" >&2
}

echo "=== Health Check Complete ===" >&2

exit $overall_status
