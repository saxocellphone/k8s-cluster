#!/bin/bash

# PostgreSQL Backup Script for *arr Services
# Backs up all databases to NFS storage (safe for backup storage)

KUBECONFIG_FILE="kubeconfig"
NAMESPACE="torrenting"
POSTGRES_POD="postgres-0"
BACKUP_DIR="/mnt/nfs/kubernetes/postgres-backups"
DATE=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS=7

echo "=========================================="
echo "PostgreSQL Backup - $(date)"
echo "=========================================="

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Database list
DATABASES=(
  "prowlarr_main"
  "prowlarr_log"
  "radarr_main"
  "radarr_log"
  "sonarr_main"
  "sonarr_log"
  "readarr_main"
  "readarr_log"
  "readarr_cache"
)

# Backup each database
for DB in "${DATABASES[@]}"; do
  echo "Backing up $DB..."
  kubectl --kubeconfig="$KUBECONFIG_FILE" -n "$NAMESPACE" exec "$POSTGRES_POD" -- \
    pg_dump -U arr_user "$DB" > "$BACKUP_DIR/${DB}_${DATE}.sql"

  if [ $? -eq 0 ]; then
    echo "  ✓ $DB backed up successfully"
    # Compress the backup
    gzip "$BACKUP_DIR/${DB}_${DATE}.sql"
    echo "  ✓ Compressed to ${DB}_${DATE}.sql.gz"
  else
    echo "  ✗ Failed to backup $DB"
  fi
done

echo ""
echo "Cleaning up old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "  ✓ Cleanup complete"

echo ""
echo "=========================================="
echo "Backup Complete!"
echo "=========================================="
echo "Backup location: $BACKUP_DIR"
echo "Backup date: $DATE"
echo ""
echo "To restore a database:"
echo "  gunzip BACKUP_FILE.sql.gz"
echo "  kubectl --kubeconfig=$KUBECONFIG_FILE -n $NAMESPACE exec -i $POSTGRES_POD -- psql -U arr_user DATABASE_NAME < BACKUP_FILE.sql"
echo ""
