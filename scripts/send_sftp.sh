#!/bin/bash

# loading the .env file
if [ ! -f "$(dirname "$0")/.env" ]; then RETURN_CODE=1; critical "No environment file, use the sample file"; fi
set -a
source "$(dirname "$0")/.env"
set +a

# Check if there are files to upload
if [ -z "$(ls -A $BACKUP_DIR)" ]; then
    echo "🚫 No files to upload. Exiting..."
    exit 1
fi

echo "🔹 Uploading backups to SFTP server ($SFTP_HOST)..."

# Use SFTP to transfer files
sftp -P $SFTP_PORT $SFTP_USER@$SFTP_HOST <<EOF
cd $SFTP_DIR
mput $BACKUP_DIR/*
bye
EOF

# Check if upload was successful
if [ $? -eq 0 ]; then
    echo "✅ Upload successful! Deleting local backups..."
    #rm -rf $BACKUP_DIR/*
    echo "🗑️ Local backups deleted."
else
    echo "❌ Upload failed! Local backups were NOT deleted."
    exit 1
fi

echo "🎉 Backup upload completed!"

exit 0
