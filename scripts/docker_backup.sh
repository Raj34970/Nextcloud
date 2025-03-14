#!/bin/bash

# Define backup directory
BACKUP_DIR="./docker_backups"
mkdir -p "$BACKUP_DIR"

# Check if at least one container is provided
if [ $# -eq 0 ]; then
    echo "❌ Please provide at least one container name or ID to back up."
    echo "Usage: ./docker_backup.sh <container_name_1> <container_name_2> ..."
    exit 1
fi

# Loop through each container provided as argument
for CONTAINER in "$@"; do
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Commit the container as an image
    IMAGE_NAME="backup_${CONTAINER}_${TIMESTAMP}"
    docker commit "$CONTAINER" "$IMAGE_NAME"
    
    # Save the image as a tar file
    IMAGE_TAR="$BACKUP_DIR/${IMAGE_NAME}.tar"
    docker save -o "$IMAGE_TAR" "$IMAGE_NAME"
    
    echo "✅ Container $CONTAINER backed up as $IMAGE_TAR"
    
    # Get the volume names associated with the container
    VOLUMES=$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "$CONTAINER")
    
    # Backup each volume
    for VOLUME in $VOLUMES; do
        VOLUME_TAR="$BACKUP_DIR/volume_${VOLUME}_${TIMESTAMP}.tar.gz"
        docker run --rm -v "$VOLUME":/data -v "$BACKUP_DIR":/backup alpine tar czf "/backup/$(basename $VOLUME_TAR)" /data
        echo "✅ Volume $VOLUME backed up as $VOLUME_TAR"
    done
done

echo "🎉 Backup completed! Files are saved in $BACKUP_DIR"
