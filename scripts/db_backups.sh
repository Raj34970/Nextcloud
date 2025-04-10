#!/bin/bash

# setting the vars
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
RETURN_CODE=0

if [ ! -f "$(dirname "$0")/.env" ]; then RETURN_CODE=1; critical "No environment file, use the sample file"; fi
set -a

source "$(dirname "$0")/.env"
set +a

# Create backup directory if not exists
sudo mkdir -p "$BACKUP_DIR"

echo "🔹 Starting Nextcloud SQL backup at $TIMESTAMP..."

# Backup MariaDB database inside the container
echo "🗄️ Dumping Nextcloud database..."
sudo docker exec -e MYSQL_PWD="$PASSWORD" "$DB_CONTAINER" mysqldump -u nextcloud nextcloud > "$BACKUP_DIR/nextcloud-db_$TIMESTAMP.sql"

echo "✅ Backup completed! File saved to: $BACKUP_DIR/nextcloud-db_$TIMESTAMP.sql"
