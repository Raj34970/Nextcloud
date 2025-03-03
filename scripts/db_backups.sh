#!/bin/bash

# Set container name
MARIADB_CONTAINER="mariadb"

# Set backup destination on the VM
BACKUP_DIR="/backup/nextcloud"
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

# Create backup directory if not exists
sudo mkdir -p "$BACKUP_DIR"

echo "🔹 Starting Nextcloud SQL backup at $TIMESTAMP..."

# Backup MariaDB database inside the container
echo "🗄️ Dumping Nextcloud database..."
sudo docker exec "$MARIADB_CONTAINER" mysqldump -u nextcloud --password='Nextcloud2024@%' nextcloud > "$BACKUP_DIR/nextcloud-db_$TIMESTAMP.sql"

echo "✅ Backup completed! File saved to: $BACKUP_DIR/nextcloud-db_$TIMESTAMP.sql"
