#!/bin/bash
set -euo pipefail

BACKUP_DIR="/root/nextcloud_backups"
RETENTION_DAYS=20

info() {
  echo -e "\033[1;34m[INFO]\033[0m $*"
}

critical() {
  echo -e "\033[1;31m[CRITICAL]\033[0m $*" >&2
}

# Ensure running as root (for SFTP backup dir access)
if [[ $EUID -ne 0 ]]; then
  critical "This script must be run with sudo or as root."
  exit 1
fi

# Check directory exists
if [ ! -d "$BACKUP_DIR" ]; then
  critical "Backup directory not found: $BACKUP_DIR"
  exit 1
fi

info "🧹 Cleaning up backups older than $RETENTION_DAYS days in $BACKUP_DIR"

# List old files before deleting
OLD_FILES=$(find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -name "nextcloud-*" 2>/dev/null)

if [[ -z "$OLD_FILES" ]]; then
  info "No backups older than $RETENTION_DAYS days found."
else
  echo "$OLD_FILES" | while read -r file; do
    info "Deleting: $file"
    rm -f "$file"
  done
fi

info "✅ Cleanup complete."
