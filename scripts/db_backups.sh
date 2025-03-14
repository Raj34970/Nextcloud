#!/bin/bash

# Set container name
MARIADB_CONTAINER="mariadb"
NEXTCLOUD_PASSWORD='Nextcloud2024@%'

# Set backup destination on the VM
BACKUP_DIR="/backup/nextcloud"
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

# Create backup directory if not exists
sudo mkdir -p "$BACKUP_DIR"

echo "🔹 Starting Nextcloud SQL backup at $TIMESTAMP..."

# Backup MariaDB database inside the container
echo "🗄️ Dumping Nextcloud database..."
sudo docker exec -e MYSQL_PWD="$PASSWORD" "$MARIADB_CONTAINER" mysqldump -u nextcloud nextcloud > "$BACKUP_DIR/nextcloud-db_$TIMESTAMP.sql"

echo "✅ Backup completed! File saved to: $BACKUP_DIR/nextcloud-db_$TIMESTAMP.sql"
