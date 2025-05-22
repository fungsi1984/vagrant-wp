#!/usr/bin/env bash

# Install Remi repository for PHP 8.4
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
dnf module enable -y php:remi-8.4

# Install NGINX, PHP-FPM and MariaDB
dnf install -y nginx php-fpm mariadb-server
dnf install -y php-fpm php-mysqlnd php-json php-gd php-xml php-mbstring php-curl

# Make sure directories exist
mkdir -p /vagrant/app/wordpress

# Configure NGINX by copying our prepared config
cp /vagrant/provision/nginx/wordpress.conf /etc/nginx/nginx.conf

# Create test file to verify web server
echo "<?php phpinfo(); ?>" > /vagrant/app/wordpress/test.php

# Configure PHP-FPM
sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf

# Make sure listen.owner and listen.group are set correctly
sed -i 's/;listen.owner = nobody/listen.owner = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen.group = nobody/listen.group = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/listen.acl_users = apache,nginx/listen.acl_users = nginx/g' /etc/php-fpm.d/www.conf || true

# Fix socket permissions
sed -i 's|listen = 127.0.0.1:9000|listen = /var/run/php-fpm/www.sock|g' /etc/php-fpm.d/www.conf || true

# Enable error reporting in PHP
sed -i 's/display_errors = Off/display_errors = On/g' /etc/php.ini
sed -i 's/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/g' /etc/php.ini

# Initialize MariaDB if needed
mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql || true

# Configure firewall if it's running
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
    echo "Firewall configured for HTTP"
fi

# Start services
systemctl start mariadb
systemctl start php-fpm
systemctl start nginx

# Secure MariaDB installation and set root password
# For older MariaDB versions
cat > /tmp/mysql_init.sql << EOF
UPDATE mysql.user SET Password=PASSWORD('rootpass') WHERE User='root';
FLUSH PRIVILEGES;
EOF

# Try the old method first
mysql -u root < /tmp/mysql_init.sql || true

# For newer MariaDB versions
cat > /tmp/mysql_secure.sql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpass';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

# Try the newer method if the first one fails
mysql -u root -p'rootpass' < /tmp/mysql_secure.sql || mysql -u root < /tmp/mysql_secure.sql || true

# Clean up temporary files
rm -f /tmp/mysql_init.sql /tmp/mysql_secure.sql

# Create database and user for WordPress
cat > /tmp/wp_db_setup.sql << EOF
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wordpressuser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpressuser'@'localhost';
FLUSH PRIVILEGES;
EOF

# Apply WordPress database setup - try multiple authentication methods
mysql -u root -p'rootpass' < /tmp/wp_db_setup.sql || mysql -u root < /tmp/wp_db_setup.sql || echo "Failed to set up WordPress database"
rm -f /tmp/wp_db_setup.sql

# WordPress files should already be in /vagrant/app/wordpress
# Make sure the directory exists
if [ ! -d "/vagrant/app/wordpress" ] || [ ! -f "/vagrant/app/wordpress/wp-config-sample.php" ]; then
  echo "WordPress files not found in /vagrant/app/wordpress!"
  echo "Please download WordPress locally before provisioning."
  exit 1
fi

# Fix permissions - this is critical for NGINX to access files
chown -R nginx:nginx /vagrant/app
chmod -R 755 /vagrant/app
# Make wp-content writable
chmod -R 775 /vagrant/app/wordpress/wp-content

# Verify permissions
ls -la /vagrant/app/wordpress/

# SELinux might be blocking access - set permissive mode or appropriate context
if command -v setenforce &> /dev/null; then
  setenforce 0 || true
  echo "Set SELinux to permissive mode"
  
  # Set proper SELinux context if SELinux is enabled
  if command -v chcon &> /dev/null; then
    chcon -R -t httpd_sys_content_t /vagrant/app
    echo "Set SELinux context for web content"
  fi
fi

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

# Make sure the php-fpm socket directory exists and has correct permissions
mkdir -p /var/run/php-fpm
chown -R nginx:nginx /var/run/php-fpm
chmod 755 /var/run/php-fpm

# Restart services
systemctl restart php-fpm
systemctl restart nginx
systemctl restart mariadb

# Check if NGINX can access the socket
ls -la /var/run/php-fpm/
echo "PHP-FPM socket permissions:"
ls -la /var/run/php-fpm/www.sock || echo "Socket not found"

# Test nginx configuration
nginx -t

# Show status
echo "NGINX Status:"
systemctl status nginx --no-pager

echo "PHP-FPM Status:"
systemctl status php-fpm --no-pager

echo "MariaDB Status:"
systemctl status mariadb --no-pager

echo "Listening ports:"
ss -tulpn | grep -E ':(80|443)'

echo "WordPress installed!"
echo "Visit http://localhost:8080 to complete setup"