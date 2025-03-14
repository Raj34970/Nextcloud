#!/bin/bash

# Exit immediately if any command fails
set -e

# Check if a date argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 YYYY-MM-DD (e.g., $0 2025-02-23)"
    exit 1
fi

BACKUP_DATE="$1"
SFTP_USER="root"
SFTP_HOST="sftp-home"
BACKUP_DIR="/home/jenkins/backups"
SFTP_DIR="/root/nextcloud_backups"
NEXTCLOUD_DIR="/var/www/html/nextcloud"
DATA_DIR="$NEXTCLOUD_DIR/data"
DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASSWORD="Nextcloud2024@%"

# Ensure backup directory exists
setup_backup_dir() {
    mkdir -p $BACKUP_DIR
    cd $BACKUP_DIR
}

# Download backup files from SFTP
download_backups() {
    echo "=== Downloading Backup Files from SFTP ==="
    sftp $SFTP_USER@$SFTP_HOST <<EOF
get ${SFTP_DIR}/nextcloud-config_${BACKUP_DATE}_*.tar.gz $BACKUP_DIR/nextcloud-config_${BACKUP_DATE}.tar.gz
get ${SFTP_DIR}/nextcloud-data_${BACKUP_DATE}_*.tar.gz $BACKUP_DIR/nextcloud-data_${BACKUP_DATE}.tar.gz
get ${SFTP_DIR}/nextcloud-db_${BACKUP_DATE}_*.sql $BACKUP_DIR/nextcloud-db_${BACKUP_DATE}.sql
EOF
}


# Locate backup files
find_backup_files() {
    CONFIG_BACKUP=$(ls nextcloud-config_${BACKUP_DATE}_*.tar.gz 2>/dev/null || true)
    DATA_BACKUP=$(ls nextcloud-data_${BACKUP_DATE}_*.tar.gz 2>/dev/null || true)
    DB_BACKUP=$(ls nextcloud-db_${BACKUP_DATE}_*.sql 2>/dev/null || true)
    
    if [ -z "$CONFIG_BACKUP" ] || [ -z "$DATA_BACKUP" ] || [ -z "$DB_BACKUP" ]; then
        echo "Error: Backup files for $BACKUP_DATE not found!"
        exit 1
    fi
}

# Stop services
stop_services() {
    echo "=== Stopping Nginx & MySQL ==="
    sudo systemctl stop nginx || { echo "Failed to stop Nginx"; exit 1; }
    # sudo systemctl stop mysql || { echo "Failed to stop MySQL"; exit 1; }
}

# Restore Nextcloud configuration
restore_config() {
    echo "=== Restoring Config ==="
    sudo tar -xzf $CONFIG_BACKUP -C $NEXTCLOUD_DIR || { echo "Failed to restore config"; exit 1; }
}

# Restore Nextcloud data
restore_data() {
    echo "=== Restoring Data (This might take some time) ==="
    sudo rm -rf $DATA_DIR || { echo "Failed to remove old data"; exit 1; }
    sudo tar -xzf $DATA_BACKUP -C /var/www/html/nextcloud/ || { echo "Failed to restore data"; exit 1; }
}

# Set correct permissions
set_permissions() {
    echo "=== Setting Correct Permissions ==="
    sudo chown -R www-data:www-data $NEXTCLOUD_DIR || { echo "Failed to set ownership"; exit 1; }
    sudo chmod -R 750 $NEXTCLOUD_DIR || { echo "Failed to set permissions"; exit 1; }
}

# Restore database and create user if not exists
restore_database() {
    echo "=== Dropping and Restoring Database ==="
    # Drop and recreate the database
    sudo mysql -u root -e "DROP DATABASE IF EXISTS $DB_NAME; CREATE DATABASE $DB_NAME;" || { echo "Failed to recreate database"; exit 1; }
    # Create user if it doesn't exist
    sudo mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';" || { echo "Failed to create database user"; exit 1; }
    # Grant privileges to the user
    sudo mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;" || { echo "Failed to grant privileges"; exit 1; }
    # Restore the database from backup
    sudo mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME < $BACKUP_DIR/$DB_BACKUP || { echo "Failed to restore database"; exit 1; }
    echo "=== Database Restored Successfully ==="
}


# Restart services
start_services() {
    echo "=== Restarting Services ==="
    # sudo systemctl start mysql || { echo "Failed to start MySQL"; exit 1; }
    sudo systemctl start nginx || { echo "Failed to start Nginx"; exit 1; }
}

# Run Nextcloud file scan
run_file_scan() {
    echo "=== Running Nextcloud File Scan ==="
    sudo -u www-data php $NEXTCLOUD_DIR/occ files:scan --all || { echo "File scan failed"; exit 1; }
}

# Main execution
setup_backup_dir

# download_backups
find_backup_files
# stop_services
# restore_config
# restore_data
# set_permissions
restore_database
start_services
run_file_scan

echo "=== Restore Completed Successfully for $BACKUP_DATE! ==="
