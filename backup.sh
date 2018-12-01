#!/bin/bash


function fatal() {
    cat <<< "$@" 1>&2
    exit 1
}

OCC_CMD='docker-compose exec -T -u www-data app php occ'

function ExitMaintenance() {
    echo "Exiting maintenance mode..."
    ${OCC_CMD} maintenance:mode --off
    echo "Done"
    echo
}


#
# Capture CTRL-C
#
trap Cancel INT

function Cancel() {
    read -p "Backup cancelled. Keep maintenance mode? [y/n] " -n 1 -r
    echo

    if ! [[ ${REPLY} =~ ^[Yy]$ ]]; then
        ExitMaintenance
    else
        echo "Maintenance mode still enabled."
    fi

    exit 1
}


#
# Can ONLY be run as root
#
[ "$(id -u)" != "0" ] && fatal "FATAL: This script has to be run as root!"


# TODO: customize the directory to store the backup data
backup_dir='/mnt/wd-disk/backup/nextcloud'
backup_root_dir="${backup_dir}/root"
backup_data_dir="${backup_dir}/data"
backup_db_dir="${backup_dir}/db"

mkdir -p ${backup_root_dir} ${backup_data_dir} ${backup_db_dir}


#
# Enter maintenance
#
echo "Entering maintenance mode..."
${OCC_CMD} maintenance:mode --on
echo "Done"
echo


# TODO: customize the nextcloud folder on host machine to backup, including
# data, config, theme folders.
install_to_backup='/home/murray/nextcloud/root'
data_to_backup='/home/murray/nextcloud/data'

echo "Creating backup of whole nextcloud install and data folder..."
rsync -av ${install_to_backup} ${backup_root_dir}
rsync -av ${data_to_backup} ${backup_data_dir}
echo "Done"
echo


#
# Backup DB
#
# TODO: customize the following db related info
db_user='nextcloud'
db_password='nextcloud'
db_name='nextcloud'

db_backup_file="db-$(date +'%Y%m%d_%H%M%S').sql"

echo "Creating backup of nextcloud database..."
docker-compose exec -T db bash -c "mysqldump --single-transaction \
    -h localhost -u ${db_user} -p${db_password} ${db_name} \
    > /tmp/${db_backup_file}"
docker cp "$(docker-compose ps -q db)":/tmp/${db_backup_file} ${backup_db_dir}
echo "Done"
echo


#
# Exit maintenance
#
ExitMaintenance


#
# Check the backup successful or not
#
[[ ! -f "${backup_db_dir}/${db_backup_file}" ]] && \
    fatal "FATAL: ${db_backup_file} failed to backup!"


#
# Remove old DB backups
#

# TODO: customize the number of backup to save
num_backups_keep=2
db_backup_pattern="${backup_db_dir}/db-*.sql"

if (( ${num_backups_keep} != 0 )); then
    num_backups=$(ls -l ${db_backup_pattern} | wc -l)

    if (( ${num_backups} > ${num_backups_keep} )); then
        echo "Removing old DB backups..."
        ls -t ${db_backup_pattern} \
            | tail -$(( num_backups - num_backups_keep )) \
            | while read backup_to_remove; do
                echo "${backup_to_remove}"
                rm -r ${backup_to_remove}
                echo "Done"
                echo
            done
    fi
fi


echo "ALL DONE!"
echo
