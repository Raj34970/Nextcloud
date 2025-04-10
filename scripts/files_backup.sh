#!/bin/bash

# setting the vars
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
RETURN_CODE=0

# loading the .env file
if [ ! -f "$(dirname "$0")/.env" ]; then RETURN_CODE=1; critical "No environment file, use the sample file"; fi
set -a
source "$(dirname "$0")/.env"
set +a

# Create backup directory if not exists
sudo mkdir -p "$BACKUP_DIR"

echo "🔹 Starting Nextcloud files backup at $TIMESTAMP..."

# Backup Nextcloud data
echo "📂 Backing up Nextcloud data..."
sudo docker exec "$NEXTCLOUD_CONTAINER" tar czf /tmp/nextcloud-data.tar.gz -C /var/www/html data
sudo docker cp "$NEXTCLOUD_CONTAINER":/tmp/nextcloud-data.tar.gz "$BACKUP_DIR/nextcloud-data_$TIMESTAMP.tar.gz"

# Backup Nextcloud config & apps
echo "⚙️ Backing up Nextcloud config & apps..."
sudo docker exec "$NEXTCLOUD_CONTAINER" tar czf /tmp/nextcloud-config.tar.gz -C /var/www/html config apps
sudo docker cp "$NEXTCLOUD_CONTAINER":/tmp/nextcloud-config.tar.gz "$BACKUP_DIR/nextcloud-config_$TIMESTAMP.tar.gz"

# Cleanup temporary files inside containers
echo "🧹 Cleaning up temporary files..."
sudo docker exec "$NEXTCLOUD_CONTAINER" rm /nextcloud-data.tar.gz /nextcloud-config.tar.gz

echo "✅ Backup completed! Files are stored in: $BACKUP_DIR"

# Optional: Remove old backups (older than 7 days)
sudo find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "🗑️ Old backups older than 7 days deleted."

exit 0
