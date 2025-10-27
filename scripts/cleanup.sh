#!/bin/bash 
echo "Cleaning up the container backup from $BACKUP_DIR"
sudo docker exec rm -rf "$NEXTCLOUD_CONTAINER":"$BACKUP_DIR"/*
