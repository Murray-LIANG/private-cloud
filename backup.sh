#!/bin/bash


function fatal() {
    cat <<< "$@" 1>&2
    exit 1
}

OCC_CMD='docker-compose exec -u www-data app php occ'

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
backup_root_dir='/mnt/wd-disk/backup/nextcloud'
backup_dir="${backup_root_dir}/$(date +'%Y%m%d_%H%M%S')"

[ -d "${backup_dir}" ] && \
    fatal "FATAL: The backup dir ${backup_dir} already exists!"

mkdir -p ${backup_dir}


#
# Enter maintenance
#
echo "Entering maintenance mode..."
${OCC_CMD} maintenance:mode --on
echo "Done"
echo


#
# Backup whole nextcloud install and data folder
#
install_file='install.tar.gz'
data_file='data.tar.gz'

# TODO: customize the nextcloud folder on host machine to backup, including
# data, config, theme folders.
install_to_backup='/home/murray/nextcloud/root'
data_to_backup='/home/murray/nextcloud/data'

echo "Creating backup of whole nextcloud install and data folder..."
tar -cpzf "${backup_dir}/${install_file}" -C ${install_to_backup} .
tar -cpzf "${backup_dir}/${data_file}" -C ${data_to_backup} .
echo "Done"
echo


#
# Backup DB
#
# TODO: customize the following db related info
db_user='nextcloud'
db_password='nextcloud'
db_name='nextcloud'

db_file='db.sql'

echo "Creating backup of nextcloud database..."
docker-compose exec db bash -c "mysqldump --single-transaction \
    -h localhost -u ${db_user} -p${db_password} ${db_name} > /tmp/${db_file}"
docker cp "$(docker-compose ps -q db)":/tmp/${db_file} ${backup_dir}
echo "Done"
echo


#
# Exit maintenance
#
ExitMaintenance


#
# Check the backup successful or not
#
[[ ! -f "${backup_dir}/${install_file}" ]] && \
    fatal "FATAL: ${install_file} failed to backup!"
[[ ! -f "${backup_dir}/${data_file}" ]] && \
    fatal "FATAL: ${data_file} failed to backup!"
[[ ! -f "${backup_dir}/${db_file}" ]] && \
    fatal "FATAL: ${db_file} failed to backup!"


#
# Remove old backups
#

# TODO: customize the number of backup to save
num_backups_keep=2

if (( ${num_backups_keep} != 0 )); then
    num_backups=$(ls -l ${backup_root_dir} | grep -c ^d)

    if (( ${num_backups} > ${num_backups_keep} )); then
        echo "Removing old backups..."
        ls -t ${backup_root_dir} | tail -$(( num_backups - num_backups_keep )) \
            | while read dir_to_remove; do
                echo "${dir_to_remove}"
                rm -r ${backup_root_dir}/${dir_to_remove}
                echo "Done"
                echo
            done
    fi
fi


echo "ALL DONE!"
echo
