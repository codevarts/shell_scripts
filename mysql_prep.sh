#!/bin/bash

# author:	Ross McEwen-Page
# purpose:	This script is an extension script used when deploying
# 		   	an Azure VM via PowerShell, it should reside in an
#          	Azure storage account. It will deploy and secure 
#		   	MySql Server on the target VM.
# notes:   	This script assumes there is an additional data disk
#		   	attached to the VM and the internal disk name is sdc
#          	(use sudo lsblk to view disks)

# variables
MYSQL_PASSWORD=''

# choose partitioning standard for new drive
parted /dev/sdc mklabel msdos

# create primary partition
parted -a opt /dev/sdc mkpart primary ext4 0% 100%

# create file system
mkfs.ext4 -L data /dev/sdc1

# create new directory to mount new drive
mkdir -p /mnt/data

# edit fstab to automount on startup
sh -c 'echo "LABEL=data /mnt/data ext4 defaults 0 2" >> /etc/fstab'

# mount the new disk
mount -a

# update apt-cache
apt-get update

# install ntp
apt-get install ntp -y

# set timezone
timedatectl set-timezone Australia/Melbourne

# install mysql-server
debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_PASSWORD"
apt-get -y install mysql-server

apt-get -y install expect
# secure mysql installation
SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"$MYSQL_PASSWORD\r\"

expect \"Validate password plugin?\"
send \"y\r\"

expect \"Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG:\"
send \"1\r\"

expect \"Change the root password?\"
send \"n\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")

echo "$SECURE_MYSQL"

# allow remote log in by commenting out bind directive
sed -i ' /^[#]*\s*bind-address/c\# bind-address = 127.0.0.1' /etc/mysql/mysql.conf.d/mysqld.cnf

# restart mysql server
systemctl restart mysql.service

# move mysql data directory
systemctl stop mysql.service

# copy data to directories to new location
rsync -av /var/lib/mysql /mnt/data

# rename original files to remove confusion
mv /var/lib/mysql /var/lib/mysql.bak

# point config to new data directory
sed -i ' /^datadir/c\datadir\t\t= /mnt/data/mysql ' /etc/mysql/mysql.conf.d/mysqld.cnf

# update apparmor access control rules
sh -c 'echo "alias /var/lib/mysql/ -> /mnt/data/mysql/," >> /etc/apparmor.d/tunables/alias'

# restart apparmor
systemctl restart apparmor

# create a ghost directory for mysql's startup scripts
mkdir /var/lib/mysql/mysql -p

# start mysql server
systemctl start mysql.service

# remove old backup
rm -Rf /var/lib/mysql.bak
