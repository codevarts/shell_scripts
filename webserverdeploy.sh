#!/bin/bash

# variable setup
appname='codevarts.com'

# update package database and upgrade any packages
echo ' #### Updating and upgrading packages '
apt update
apt upgrade -y

# update hostname
echo ' #### Updating hostname'
sed -i " s/$(hostname)/$(appname)/g " /etc/hostname

# install management tools
echo ' #### Installing management tools'
apt install ntp tree htop iotop iptraf curl git unzip -y

# set timezone to melbourne
echo ' #### Set correct timezone'
timedatectl set-timezone Australia/Melbourne

# install Apache, php and php requirements/tools
echo ' #### Install Apache and PHP'
apt install apache2 php7.0 libapache2-mod-php7.0 php7.0-mcrypt php7.0-mysql php7.0-cli php7.0-xml php7.0-mbstring php7.0-gd php7.0-curl -y

# update directory to serve php files first
echo ' #### Updating dir.conf to server php files first'
sed -i ' s/index.html/index.php/g ' /etc/apache2/mods-enabled/dir.conf
sed -i ' s/index.php/index.html/2 ' /etc/apache2/mods-enabled/dir.conf

# enable apache modules
echo ' #### Enabling Apache modules'
a2enmod rewrite ssl headers

# stop apache
echo ' #### Stopping Apache'
systemctl stop apache2

# remove comments from web.conf files
echo ' #### Remove comments from web conf files'
sed -i.bak -e ' /^\t#/d;/^$/d ' /etc/apache2/sites-available/000-default.conf
sed -i.bak -e ' /^[\t]*#/d ' /etc/apache2/sites-available/default-ssl.conf

# add server name and admin to default site
echo ' #### Adding server name to http site'
sed -i ' /<VirtualHost\s\*:80>/a \\tServerName codevarts.com ' /etc/apache2/sites-available/000-default.conf

# change admin 
echo ' #### Changing server admin for http site'
sed -i ' s/webmaster@localhost/admin@codevarts.com/ ' /etc/apache2/sites-available/000-default.conf

# server name for ssl site
echo ' #### Adding server name to https site'
sed -i ' /<VirtualHost\s_default_:443>/a \\t\\tServerName codevarts.com ' /etc/apache2/sites-available/default-ssl.conf

# change admin 
echo ' #### Changing server admin for https site'
sed -i ' s/webmaster@localhost/admin@codevarts.com/ ' /etc/apache2/sites-available/default-ssl.conf

# add content security headers
echo ' #### Adding security headers to https conf'
sed -i ' /SSLEngine\son/a \
\n\t\t# Guarantee HTTPS for 1 year including Dub Domains \
\t\tHeader always set Strict-Transport-Security "max-age=31536000; includeSubDomains" \
\t\tHeader set X-Content-Type-Options "nosniff" \
\t\tHeader set X-XSS-Protection "1; mode=block" \
\t\tHeader set X-Frame-Options "SAMEORIGIN" \
\t\tHeader unset Content-Security-Policy \
\t\tHeader add Content-Security-Policy "default-src 'unsafe-inline' 'unsafe-eval' 'self' *.ws.sharethis.com *.maps.googleapis.com *.bootstrapcdn.com weloveiconfonts.com *.googletagmanager.com *.google-analytics.com *.optmstr.com *.optnmstr.com *.hotjar.com *.facebook.net *.g.doubleclick.net *.google.com *.google.com.au *.visualwebsiteoptimizer.com *.likebtn.com *.sharethis.com *.facebook.com data:;" \
\t\tHeader add Content-Security-Policy "img-src 'unsafe-inline' 'self' *.google.com *.likebtn.com *.sharethis.com *.facebook.com *.google-analytics.com *.visualwebsiteoptimizer.com *.facebook.com *.google.com.au *.g.doubleclick.net *.googletagmanager.com data:;" \
\t\tHeader edit Set-Cookie ^(.*)$ $1;HttpOnly;Secure \ ' /etc/apache2/sites-available/default-ssl.conf

# install composer globally
# download installer and dump in tmp folder
echo ' #### Downloading Composer'
curl -sS https://getcomposer.org/installer > /tmp/composer-setup.php

# install
echo ' #### Installing Composer'
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

# remove default file from apache index
echo ' #### Remove default webpage'
rm -f /var/www/html/index.html

# download drupal to web directory and change into directory
echo ' #### Downloading Drupal and changing to /var/www/html directory'
cd /var/www/html
curl -O https://ftp.drupal.org/files/projects/drupal-8.5.3.tar.gz

# extract drupal inplace
echo ' #### Extracting Drupal inplace from tar'
tar --strip-components=1 -xzf drupal-8.5.3.tar.gz

# remove installation file
echo ' #### Removing the Drupal installation files'
rm -fr drupal-8.5.3.tar.gz

# make composer.json/lock writable
echo ' #### Making Composer files writable'
chmod 777 composer.json
chmod 777 composer.lock

# open the vendor directory up for deployment
echo ' #### open vender directory up for deployment'
chmod 777 -R vendor

# require drush (must be run as non root user)
echo ' #### Adding drush requirement'
sudo -u [local non sudo user] bash -c 'composer require drush/drush'

# create a copy of the drupal default settings file and change file permissions
echo ' #### Creating a copy of the Drupal default site file'
install -m 777 sites/default/default.settings.php sites/default/settings.php

# make the sites file writable
echo ' #### Making the sites file writable'
chmod 777 sites/default/settings.php

# make the sites directory writable
echo ' #### Making sites directory writable'
chmod -R 777 sites/default

# start apache server
echo ' #### Starting Apache '
systemctl start apache2

