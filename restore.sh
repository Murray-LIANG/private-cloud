#!/bin/bash


function fatal() {
    cat <<< "$@" 1>&2
    exit 1
}


#
# Can ONLY be run as root
#
[ "$(id -u)" != "0" ] && fatal "FATAL: This script has to be run as root!"


#
# Check the path where the backup to restore locates is given
#
usage="\nUsage: restore.sh <path_of_backup_to_restore>\n"
[ $# != "1" ] && fatal "FATAL: No path of backup to restore given!${usage}"

backup_to_restore=$1

# TODO: customize the name of backup files
install_file='install.tar.gz'
data_file='data.tar.gz'
db_file='db.sql'

[ ! -d "${backup_to_restore}/${install_file}" ] && \
    fatal "FATAL: Backup file of nextcloud install folder not exist!${usage}"
[ ! -d "${backup_to_restore}/${data_file}" ] && \
    fatal "FATAL: Backup file of nextcloud data folder not exist!${usage}"
[ ! -d "${backup_to_restore}/${db_file}" ] && \
    fatal "FATAL: Backup file of nextcloud db not exist!${usage}"

#
# Enter maintenance
#
echo "Entering maintenance mode..."
${OCC_CMD} maintenance:mode --on
echo "Done"
echo


# TODO: customize the directory of nextcloud install and data
nextcloud_root_dir='/home/murray/nextcloud/root'
nextcloud_data_dir='/home/murray/nextcloud/data'


#
# Remove old nextcloud folders
#
echo "Removing old nextcloud install folder..."
rm -r "${nextcloud_root_dir}"
mkdir -p "${nextcloud_root_dir}"
echo "Done"
echo


echo "Removing old nextcloud data folder..."
rm -r "${nextcloud_data_dir}"
mkdir -p "${nextcloud_data_dir}"
echo "Done"
echo


#
# Restore nextcloud folders
#
echo "Restoring nextcloud install folder..."
tar -xmpzf "${backup_to_restore}/${install_file}" -C ${nextcloud_root_dir}
echo "Done"
echo


echo "Restoring nextcloud data folder..."
tar -xmpzf "${backup_to_restore}/${data_file}" -C ${nextcloud_data_dir}
echo "Done"
echo


#
# Restore database
#
# TODO: customize the following db related info
db_user='nextcloud'
db_password='nextcloud'
db_name='nextcloud'

echo "Dropping old nextcloud database..."
docker-compose exec db bash -c "mysql -h localhost -u ${db_user} \
    -p${db_password} -e \"DROP DATABASE ${db_name}\""
echo "Done"
echo

echo "Creating new nextcloud database..."
docker-compose exec db bash -c "mysql -h localhost -u ${db_user} \
    -p${db_password} -e \"CREATE DATABASE ${db_name}\""
echo "Done"
echo

echo "Restoring nextcloud database..."
docker cp ${backup_to_restore}/${db_file} \
    "$(docker-compose ps -q db)":/tmp/${db_file}
docker-compose exec db bash -c "mysql -h localhost -u ${db_user} \
    -p${db_password} ${db_name} < /tmp/${db_file}"
echo "Done"
echo


#
# Set folders permissions
#
echo "Setting permissions for nextcloud install and data folders..."
chown -R www-data:www-data ${nextcloud_root_dir}
chown -R www-data:www-data ${nextcloud_data_dir}
echo "Done"
echo


#
# Exit maintenance
#
echo "Entering maintenance mode..."
${OCC_CMD} maintenance:mode --off
echo "Done"
echo


echo "ALL DONE!"
echo
