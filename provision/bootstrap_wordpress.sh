#!/usr/bin/env bash

# Install MariaDB for WordPress
dnf install -y mariadb-server
systemctl start mariadb

# Initialize MariaDB if needed
mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql || true

# Enable and ensure MariaDB is running
systemctl enable mariadb
systemctl start mariadb

# Set root password and create database
mysql -e "UPDATE mysql.user SET Password=PASSWORD('rootpass') WHERE User='root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Create database and user for WordPress
mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
mysql -e "CREATE USER IF NOT EXISTS 'wordpressuser'@'localhost' IDENTIFIED BY 'password';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpressuser'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Install PHP extensions needed for WordPress
dnf install -y php-fpm php-mysqlnd php-json php-gd php-xml php-mbstring php-curl

# Enable error reporting in PHP
sed -i 's/display_errors = Off/display_errors = On/g' /etc/php.ini
sed -i 's/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/g' /etc/php.ini

# Create WordPress directory
mkdir -p /vagrant/app/wordpress

# Download and extract WordPress
cd /tmp
curl -O https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

# Clear the WordPress directory first
rm -rf /vagrant/app/wordpress/*

# Copy WordPress files
cp -r wordpress/* /vagrant/app/wordpress/

# Fix permissions
chown -R nginx:nginx /vagrant/app
chmod -R 755 /vagrant/app
# Make wp-content writable
chmod -R 775 /vagrant/app/wordpress/wp-content

# Remove any previous wp-config.php
rm -f /vagrant/app/wordpress/wp-config.php

# Configure wp-config.php using the sample file
cp /vagrant/app/wordpress/wp-config-sample.php /vagrant/app/wordpress/wp-config.php

# Update database settings
sed -i "s/database_name_here/wordpress/" /vagrant/app/wordpress/wp-config.php
sed -i "s/username_here/wordpressuser/" /vagrant/app/wordpress/wp-config.php
sed -i "s/password_here/password/" /vagrant/app/wordpress/wp-config.php

# Make sure table_prefix is correctly defined
sed -i "s/\$table_prefix = .*/\$table_prefix = 'wp_';/" /vagrant/app/wordpress/wp-config.php

# Add debugging
sed -i "/define( 'WP_DEBUG', false );/c\define( 'WP_DEBUG', true );\ndefine( 'WP_DEBUG_LOG', true );\ndefine( 'WP_DEBUG_DISPLAY', false );" /vagrant/app/wordpress/wp-config.php

# Update nginx configuration for WordPress
cp /vagrant/provision/nginx/wordpress.conf /etc/nginx/nginx.conf

# Restart services
systemctl restart php-fpm
systemctl restart nginx
systemctl restart mariadb

# Check for errors in nginx and PHP logs
echo "=== NGINX ERROR LOG ==="
tail /var/log/nginx/error.log || true

echo "=== PHP ERROR LOG ==="
tail /var/log/php-fpm/error.log || true

echo "=== WordPress Debug Log ==="
tail /vagrant/app/wordpress/wp-content/debug.log || true

echo "WordPress installed!"
echo "Visit http://localhost:8080 to complete setup"