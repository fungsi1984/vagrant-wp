#!/usr/bin/env bash

# Install Remi repository for PHP 8.4
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
dnf module enable -y php:remi-8.4

# Install NGINX and PHP-FPM (minimal set)
dnf install -y nginx php-fpm

# Make sure directories exist
mkdir -p /vagrant/app

# Configure NGINX by copying our prepared config
cp /vagrant/provision/nginx/nginx.conf /etc/nginx/nginx.conf

# Fix permissions
chmod -R 755 /vagrant/app
chown -R nginx:nginx /vagrant/app

# Configure PHP-FPM
sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf

# SELinux handling removed per user request

# Configure firewall if it's running
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
    echo "Firewall configured for HTTP"
fi

# Start services (without enabling them)
systemctl start php-fpm
systemctl start nginx

# Show status
echo "NGINX Status:"
systemctl status nginx --no-pager

echo "PHP-FPM Status:"
systemctl status php-fpm --no-pager

echo "Listening ports:"
ss -tulpn | grep -E ':(80|443)'