#!/bin/bash

# Must be run with sudo
BACKUP_DIR="/root/nextcloud_backups"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (via sudo)." >&2
   exit 1
fi

cd "$BACKUP_DIR" || {
    echo "Failed to access backup directory: $BACKUP_DIR" >&2
    exit 1
}

# Extract unique backup dates (YYYY-MM-DD)
dates=$(ls nextcloud-* 2>/dev/null | \
    grep -oP '\d{4}-\d{2}-\d{2}' | \
    sort | uniq)

# Get the latest date
latest_date=$(echo "$dates" | tail -n 1)

echo "Latest backup date: $latest_date"
echo "Deleting backups from older dates..."

# Delete files not from latest date
for d in $dates; do
    if [[ "$d" != "$latest_date" ]]; then
        echo "Deleting files from date: $d"
        rm -v nextcloud-*"$d"*
    fi
done

echo "Cleanup complete."