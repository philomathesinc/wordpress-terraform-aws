#!/bin/bash

PUBLIC_DNS="$(curl http://169.254.169.254/latest/meta-data/public-hostname)"
DB_HOST="$(cat /tmp/db_host)"

# Installing dependencies
sudo apt-get update && sudo apt-get install -y \
curl \
mysql-client \
nginx \
php-curl \
php-gd \
php-intl \
php-mbstring \
php-mysql \
php-soap \
php-xml \
php-xmlrpc \
php-zip \
php8.1-fpm && \
sudo systemctl restart php8.1-fpm

# Configure Nginx
sudo ufw allow 'Nginx Full' && \
sudo mkdir "/var/www/${PUBLIC_DNS}" && \
sudo chown -R "$USER":"$USER" "/var/www/${PUBLIC_DNS}" && \
sudo cp "/tmp/${PUBLIC_DNS}.conf" "/etc/nginx/sites-available/${PUBLIC_DNS}.conf" && \
sudo sed -i "s/your_domain/${PUBLIC_DNS}/g" "/etc/nginx/sites-available/${PUBLIC_DNS}.conf" && \
sudo ln -s "/etc/nginx/sites-available/${PUBLIC_DNS}.conf" /etc/nginx/sites-enabled/ && \
sudo unlink /etc/nginx/sites-enabled/default && \
sudo systemctl reload nginx

# Installing wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
chmod +x wp-cli.phar && \
sudo mv wp-cli.phar /usr/local/bin/wp

## Installing certbot
sudo snap install core && \
sudo snap refresh core && \
sudo apt remove certbot && \
sudo snap install --classic certbot && \
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Installing wordpress
cd "/var/www/${PUBLIC_DNS}" && \
wp core download && \
wp config create \
--dbname=wordpress \
--dbuser=wordpress \
--dbpass=wordpress \
--dbhost="${DB_HOST}" && \
wp core install \
--url="${PUBLIC_DNS}" \
--title="PhilomathesInc" \
--admin_user=Philomathes \
--admin_password=philomathes \
--admin_email=info@philomathesinc.github.io \
--skip-email