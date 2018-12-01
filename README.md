# Setup Private Cloud at Home

## Solution
- [nextcloud](https://nextcloud.com/)

Run it inside `docker container`.

## References
- https://blog.wongcw.com/2018/10/05/docker-%E6%90%AD%E5%BB%BA-nextcloud/
- https://github.com/nextcloud/docker/blob/master/README.md

## Steps
1. Install `docker`.

```bash
$ sudo apt install docker.io
$ sudo adduser murray docker
```

2. Install `docker-compose`.

```bash
$ sudo apt install -y python3 python3-pip
$ sudo pip3 install -U pip
$ sudo pip3 install setuptools docker-compose

```

3. Clone this repo.
```bash
$ mkdir ~/git
$ git clone https://github.com/Murray-LIANG/private-cloud ~/git/private-cloud
```

4. IMPORTANT: Customize the folders holding the nextcloud install, data and DB.
```bash
$ mkdir -p ~/nextcloud/root ~/nextcloud/db

# I put the data folder to the USB disk
# After edit `/etc/fstab`, reboot the computer
# `/etc/fstab` example:
$ cat /etc/fstab

# WD My Passport 2TB
UUID=F474B7AA74B76DCC   /mnt/wd-disk    ntfs-3g defaults,permissions  0   0

# Store the nextcloud data to WD My Passport
/mnt/wd-disk/nextcloud/data               /home/murray/nextcloud/data none bind

# After reboot, one time modification
$ sudo chmod -R 700 /mnt/wd-disk/nextcloud
$ sudo chown -R www-data:www-data /mnt/wd-disk/nextcloud/data
```

5. IMPORTANT: Customize `~/git/private-cloud/nextcloud.yml`.
- Update paths to the ones configured in step $4.
- Update DB user name and password.

6. Start the `nextcloud` services in container.
```bash
$ cd ~/git/private-cloud
$ sudo docker-compose up -d
```

## Backup

1. IMPORTANT: Customize the `TODO` in the `backup.sh`.

2. Do the backup.
```bash
$ sudo backup.sh

# Or set in crontab for backup at 1 a.m every day
$ sudo crontab -e

PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

# m h  dom mon dow   command
0 1 * * * cd /home/murray/git/private-cloud && ./backup.sh > /mnt/wd-disk/backup/nextcloud/$(date +'%Y%m%d_%H%M%S').log 2>&1
```

## Restore
```bash
$ sudo restore.sh
```

## Tips



