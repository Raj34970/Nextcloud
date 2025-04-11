#!/bin/bash
RETURN_CODE=0

if [ ! -f "$(dirname "$0")/.env" ]; then RETURN_CODE=1; critical "No environment file, use the sample file"; fi
set -a

source "$(dirname "$0")/.env"
set +a

# Check if a date argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 YYYY-MM-DD (e.g., $0 2025-02-23)"
    exit 1
fi

BACKUP_DATE="$1"


# Ensure backup directory exists
setup_backup_dir() {
    mkdir -p $BACKUP_DIR
    cd $BACKUP_DIR
}

# Download backup files from SFTP
download_backups() {
    echo "=== Downloading Backup Files from SFTP ==="
    sftp $SFTP_USER@$SFTP_HOST <<EOF
get ${SFTP_DIR}/nextcloud-config_${BACKUP_DATE}_*.tar.gz $BACKUP_DIR/nextcloud-config_${BACKUP_DATE}_*.tar.gz
get ${SFTP_DIR}/nextcloud-data_${BACKUP_DATE}_*.tar.gz $BACKUP_DIR/nextcloud-data_${BACKUP_DATE}_*.tar.gz
get ${SFTP_DIR}/nextcloud-db_${BACKUP_DATE}_*.sql $BACKUP_DIR/nextcloud-db_${BACKUP_DATE}_*.sql
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

# Restore Nextcloud configuration
restore_config() {
    echo "=== Restoring Config ==="
    sudo tar -xzf $CONFIG_BACKUP -C $DATA_DIR || { echo "Failed to restore config"; exit 1; }
}

# Restore Nextcloud data
restore_data() {
    echo "=== Restoring Data (This might take some time) ==="
    sudo rm -rf $DATA_DIR || { echo "Failed to remove old data"; exit 1; }
    echo "Creating a fresh data folder"
    sudo mkdir -p $DATA_DIR
    echo "=== Setting Correct Permissions to the $DATA_DIR==="
    sudo chown www-data:www-data $DATA_DIR || { echo "Failed to set ownership to the data dir"; exit 1; }
    echo "=== Massive task !! -- Extracting the files in the $DATA_DIR (This might take some time)==="
    sudo tar -xzf $DATA_BACKUP -C $DATA_DIR || { echo "Failed to restore data"; exit 1; }
    echo "=== Setting Correct Permissions ==="
    sudo chown www-data:www-data $NEXTCLOUD_DIR || { echo "Failed to set ownership"; exit 1; }
    sudo chmod 750 $NEXTCLOUD_DIR || { echo "Failed to set permissions"; exit 1; }
}

# Restore database and create user if not exists
restore_database() {
    echo "=== Dropping Database ==="
    sudo docker exec -i $DB_CONTAINER mysql -u root -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS $DB_NAME; CREATE DATABASE $DB_NAME;" || { echo "Failed to recreate database"; exit 1; }
    echo "=== Creating user if not exists ==="
    sudo docker exec -i $DB_CONTAINER mysql -u root -p"$DB_PASSWORD" -e "CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';" || { echo "Failed to create database user"; exit 1; }
    echo "=== Granting privillages to the newly created user ==="
    sudo docker exec -i $DB_CONTAINER mysql -u root -p"$DB_PASSWORD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;" || { echo "Failed to grant privileges"; exit 1; }
    echo "=== Restoring the DB with the backup file ==="
    sudo docker exec -i $DB_CONTAINER mysql -u root -p"$DB_PASSWORD" -D "$DB_NAME" < "$BACKUP_DIR/$DB_BACKUP" || { echo "Failed to restore database"; exit 1; }
    echo "=== Database Restored Successfully ==="
    echo "=== Restarting nextcloud DB and contianer ==="
    sudo docker stop $DB_CONTAINER && sudo docker stop $NEXTCLOUD_CONTAINER || { echo "Failed to stop Nextcloud and mariadb container"; exit 1; }
    sudo docker start $DB_CONTAINER && sudo docker start $NEXTCLOUD_CONTAINER || { echo "Failed to start Nextcloud and mariadb container"; exit 1; }
}

# Run Nextcloud file scan
upgrade_repair() {
    echo "=== Upgrading nextcloud & performing a repair==="
    sudo docker exec -u www-data $NEXTCLOUD_CONTAINER php $NEXTCLOUD_OCC_PATH upgrade || { echo "Uprgrade failed"; exit 1; }
    sudo docker exec -u www-data $NEXTCLOUD_CONTAINER php $NEXTCLOUD_OCC_PATH maintenance:repair || { echo "Repair failed"; exit 1; }
}



cleanup(){
    echo "Cealing up the backup dir"
    rm -Rf $BACKUP_DIR/*
}

# ===== Main execution =====
# setup_backup_dir
# download_backups
# find_backup_files
# restore_config
# restore_data
# restore_database
upgrade_repair
cleanup

echo "=== Restore Completed Successfully for $BACKUP_DATE! ==="
