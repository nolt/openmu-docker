#!/bin/bash
#
# PostgreSQL backup for the OpenMU database.
#
# Runs automatically in the openmu-db-backup container (a loop in
# docker-compose.yaml calls this on an interval), or by hand:
#
#     docker exec openmu-db-backup /usr/local/bin/backup.sh
#
# Produces a compressed custom-format dump in $BACKUP_DIR named
# openmu_YYYYMMDD_HHMMSS.dump.gz, verifies it, and prunes old backups.
#
set -uo pipefail

DB_HOST="${DB_HOST:-db}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-openmu}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEST="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Backup start: ${DB_NAME}@${DB_HOST} -> ${DEST}.gz"

# Dump in custom format. On failure: log, drop the partial file (so no orphan is
# left behind) and exit non-zero - the loop will retry on the next interval.
if ! pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -Fc -f "$DEST"; then
    log "ERROR: pg_dump failed; removing partial file"
    rm -f "$DEST"
    exit 1
fi

# Integrity check: a healthy custom-format dump can be listed by pg_restore.
if ! pg_restore --list "$DEST" >/dev/null 2>&1; then
    log "ERROR: dump failed integrity check (pg_restore --list); removing"
    rm -f "$DEST"
    exit 1
fi

# Custom format is already zlib-compressed, but gzip on top still saves ~25-30%
# across the whole file - and makes retention simple.
gzip -f "$DEST"
log "Backup OK (${DB_NAME}): $(du -h "${DEST}.gz" | cut -f1) -> ${DEST}.gz"

# Retention: drop gzipped backups AND any leftover bare .dump (e.g. from older
# failed runs) older than the window.
deleted=$(find "$BACKUP_DIR" \
    \( -name "${DB_NAME}_*.dump.gz" -o -name "${DB_NAME}_*.dump" \) \
    -mtime "+${RETENTION_DAYS}" -print -delete | wc -l)
if [ "$deleted" -gt 0 ]; then
    log "Retention: removed ${deleted} backup(s) older than ${RETENTION_DAYS} days"
fi
