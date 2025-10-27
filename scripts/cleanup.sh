#!/bin/bash 

RETURN_CODE=0

# loading the .env file
if [ ! -f "$(dirname "$0")/.env" ]; then RETURN_CODE=1; critical "No environment file, use the sample file"; fi
set -a
source "$(dirname "$0")/.env"
set +a

echo "Cleaning up the container backup from $BACKUP_DIR"
sudo docker exec "$NEXTCLOUD_CONTAINER" rm -rf "$NEXTCLOUD_CONTAINER":"$BACKUP_DIR"/*
