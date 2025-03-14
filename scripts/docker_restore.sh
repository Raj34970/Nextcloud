#!/bin/bash

# Define backup directory
BACKUP_DIR="./docker_backups"

# Check if a TIMESTAMP is provided
if [ -z "$1" ]; then
    echo "❌ Please provide a TIMESTAMP as the parameter."
    echo "Usage: ./docker_restore.sh <timestamp>"
    exit 1
fi

TIMESTAMP=$1

# Check if the backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup directory $BACKUP_DIR not found!"
    exit 1
fi

# Loop through the backup files
for IMAGE_TAR in "$BACKUP_DIR"/backup_*_"$TIMESTAMP".tar; do
    if [ -f "$IMAGE_TAR" ]; then
        IMAGE_NAME=$(basename "$IMAGE_TAR" .tar)
        
        # Load the image into Docker
        echo "✅ Restoring container image from $IMAGE_TAR..."
        docker load -i "$IMAGE_TAR"
        
        # Run the container
        echo "✅ Starting container $IMAGE_NAME..."
        docker run -d --name "$IMAGE_NAME" "$IMAGE_NAME"
    else
        echo "❌ No image backup found for timestamp $TIMESTAMP."
    fi
done

# Loop through the volume backup files
for VOLUME_TAR in "$BACKUP_DIR"/volume_*_"$TIMESTAMP".tar.gz; do
    if [ -f "$VOLUME_TAR" ]; then
        VOLUME_NAME=$(basename "$VOLUME_TAR" .tar.gz)
        
        # Create the volume if it doesn't exist
        echo "✅ Restoring volume $VOLUME_NAME from $VOLUME_TAR..."
        docker volume create "$VOLUME_NAME"
        
        # Extract the volume data
        docker run --rm -v "$VOLUME_NAME":/data -v "$BACKUP_DIR":/backup busybox tar xzf "/backup/$VOLUME_NAME.tar.gz" -C /data
    else
        echo "❌ No volume backup found for timestamp $TIMESTAMP."
    fi
done

echo "🎉 Restore process completed for timestamp $TIMESTAMP"
