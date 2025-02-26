#!/bin/bash

# SFTP Server details
SFTP_USER="root"
SFTP_HOST="sftp-home"
SFTP_PORT="22"
REMOTE_DIR="/root/nextcloud_backups"

# Local backup directory
LOCAL_BACKUP_DIR="/backup/nextcloud"

# Check if there are files to upload
if [ -z "$(ls -A $LOCAL_BACKUP_DIR)" ]; then
    echo "🚫 No files to upload. Exiting..."
    exit 1
fi

echo "🔹 Uploading backups to SFTP server ($SFTP_HOST)..."

# Use SFTP to transfer files
sftp -P $SFTP_PORT $SFTP_USER@$SFTP_HOST <<EOF
cd $REMOTE_DIR
mput $LOCAL_BACKUP_DIR/*
bye
EOF

# Check if upload was successful
if [ $? -eq 0 ]; then
    echo "✅ Upload successful! Deleting local backups..."
    #rm -rf $LOCAL_BACKUP_DIR/*
    echo "🗑️ Local backups deleted."
else
    echo "❌ Upload failed! Local backups were NOT deleted."
    exit 1
fi

echo "🎉 Backup upload completed!"

exit 0
