#!/bin/bash
LOG_DIR=/var/log/backup
# Check if a date argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 YYYY-MM-DD (e.g., $1 2025-02-23)"
    exit 1
fi
BACKUP_DATE="$1"
# initilizing the variables
RESTORE_CONFIG=nextcloud-config_${BACKUP_DATE}_*.tar.gz
RESTORE_FILE=nextcloud-data_${BACKUP_DATE}_*.tar.gz
RESTORE_DB=nextcloud-db_${BACKUP_DATE}_*.sql

COMMANDS=( 'lftp' 'info' )
source "$(dirname "$0")/log.sh"
sudo mkdir --parents "${LOG_DIR}"
sudo chown jenkins:jenkins ${LOG_DIR}
RETURN_CODE=$?
test ${RETURN_CODE} -eq 0 || error "Can not create log folder"
# Redirect stdout & stderr to restore.log and stderr to restore-err.log
exec >> >(tee -a "${LOG_DIR}/restore.log") 2>> >(tee -a "${LOG_DIR}/restore-err.log" | tee -a "${LOG_DIR}/restore.log" >&2)


# Check if required commands are available
for command in "${COMMANDS[@]}"; do
  command -v "${command}" >/dev/null 2>&1 || { >&2 RETURN_CODE=1; critical "Error, I require tool '${command}' but it's not installed, exiting"; }
done

set_env (){
    if [ ! -f "$(dirname "$0")/.env" ]; then RETURN_CODE=1; critical "No environment file, use the sample file"; fi
    set -a
    # shellcheck disable=SC1094
    source "$(dirname "$0")/.env"
    set +a
}

# Ensure backup directory exists
setup_restore_dir() {
    echo "=== Setting up restore DIR ==="
    mkdir -p $RESTORE_DIR
}

check_backup_sftp(){
    echo "=== Checking the backups ==="

    local lftp
    lftp_cmd="lftp -u ${SFTP_USER}, sftp://${SFTP_USER}@${SFTP_HOST}"       

    info "Checking remote file existence"
    # Config file
    RESOLVED_CONFIG=$(${lftp_cmd} -e "cls -1 ${SFTP_DIR}/${RESTORE_CONFIG}; bye")
    test -z "$RESOLVED_CONFIG" && critical "Backup config file not found"
    # Data file
    RESOLVED_FILE=$(${lftp_cmd} -e "cls -1 ${SFTP_DIR}/${RESTORE_FILE}; bye")
    test -z "$RESOLVED_FILE" && critical "Backup data file not found"
    # DB file
    RESOLVED_DB=$(${lftp_cmd} -e "cls -1 ${SFTP_DIR}/${RESTORE_DB}; bye")
    test -z "$RESOLVED_DB" && critical "Backup DB file not found"
    # Debug/log output
    info "Found config: $RESOLVED_CONFIG"
    info "Found file:   $RESOLVED_FILE"
    info "Found db:     $RESOLVED_DB"

}

# Download backup files from SFTP
download_backups() {
    echo "=== Downloading Backup Files from the SFTP server via LFTP ==="
    echo "SFTP_USER: $SFTP_USER, SFTP_HOST: $SFTP_HOST, SFTP_DIR: $SFTP_DIR"
    
    # Get the data, config and DB
    info "Transfering files from remote server"
    ${lftp_cmd} -e "get ${RESOLVED_CONFIG} -o ${RESTORE_DIR}; bye"
    ${lftp_cmd} -e "get ${RESOLVED_FILE} -o ${RESTORE_DIR}; bye"
    ${lftp_cmd} -e "get ${RESOLVED_DB} -o ${RESTORE_DIR}; bye"
    RETURN_CODE=$?
    test ${RETURN_CODE} -eq 0 || critical "Can not download the files from remote server"

}

# Locate backup files
find_backup_files() {
    echo ls "${RESTORE_DIR}/${RESTORE_CONFIG}"
    CONFIG_BACKUP=$(ls ${RESTORE_DIR}/${RESTORE_CONFIG} 2>/dev/null || true)
    DATA_BACKUP=$(ls ${RESTORE_DIR}/${RESTORE_FILE} 2>/dev/null || true)
    DB_BACKUP=$(ls ${RESTORE_DIR}/${RESTORE_DB} 2>/dev/null || true)
    if [ -z "$CONFIG_BACKUP" ] || [ -z "$DATA_BACKUP" ] || [ -z "$DB_BACKUP" ]; then
        echo "Error: Backup files for $BACKUP_DATE not found!"
        exit 1
    fi
}

# Restore Nextcloud configuration
restore_config() {
    echo "=== Restoring Config ==="
    sudo tar -xzf ${CONFIG_BACKUP} -C ${NEXTCLOUD_DIR} || { echo "Failed to restore config"; exit 1; }
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
    sudo tar -xzf $DATA_BACKUP -C $NEXTCLOUD_DIR || { echo "Failed to restore data"; exit 1; }
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
    echo "$DB_BACKUP"
    sudo docker exec -i $DB_CONTAINER mysql -u root -p"$DB_PASSWORD" -D "$DB_NAME" < "$DB_BACKUP" || { echo "Failed to restore database"; exit 1; }
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
    echo "=== Restore Completed Successfully for $BACKUP_DATE! ==="
}



cleanup(){
    echo "Cealing up the backup dir"
    rm -Rf $BACKUP_DIR/*
}

# ===== Main execution =====
main() {
    set_env
    setup_restore_dir
    check_backup_sftp
    # download_backups

    find_backup_files
    
    restore_config
    restore_data
    restore_database
    upgrade_repair
    cleanup
}

main
