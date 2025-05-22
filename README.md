# Vagrant WordPress Development Environment

This repository provides a simple Vagrant setup for WordPress development. It creates a virtual machine with NGINX, PHP 8.4, and MariaDB, configured to run WordPress from a shared folder.

# NOTES
- still exploring security in db, selinux

## Prerequisites

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/)

## Quick Start

1. Clone this repository:
   ```
   git clone https://github.com/fungsi1984/vagrant-wp.git
   cd vagrant-wp
   ```

2. Download and extract WordPress locally:
   ```
   mkdir -p app/wordpress
   curl -o wordpress.tar.gz https://wordpress.org/latest.tar.gz
   tar -xzf wordpress.tar.gz
   cp -r wordpress/* app/wordpress/
   rm -rf wordpress.tar.gz wordpress
   ```

3. Start the Vagrant machine:
   ```
   vagrant up
   ```

4. Access WordPress in your browser at:
   ```
   http://localhost:8080
   ```
   
   To verify PHP is working, visit:
   ```
   http://localhost:8080/test.php
   ```

5. Complete the WordPress setup in your browser

## What's Included

- AlmaLinux 8 box
- NGINX web server
- PHP 8.4 with necessary extensions
- MariaDB database
- Latest WordPress installation
- Development-friendly configuration

## Database Details

- **Database Name**: wordpress
- **Username**: wordpressuser
- **Password**: password
- **MySQL Root Password**: rootpass

## Development Workflow

1. Download WordPress locally to the `app/wordpress` directory
2. Start the VM with `vagrant up`
3. Edit WordPress files directly on your host machine in the `app/wordpress` directory
4. Changes are synced automatically to the VM through the shared folder
5. Suspend the VM when not in use with `vagrant suspend`
6. Destroy the VM when finished with `vagrant destroy`

This workflow provides several advantages:
- Faster VM provisioning since WordPress is already downloaded
- Works offline after initial download
- Better version control over WordPress files
- Easier to maintain specific WordPress versions
- More reliable setup process

## Technical Details

This Vagrant WordPress setup has been optimized to address several common issues:

- **SELinux configuration**: AlmaLinux 8 runs with SELinux enabled by default, which blocks NGINX from accessing files in the /vagrant directory. We disabled it with `setenforce 0` and set the proper context.

- **PHP-FPM socket configuration**: Properly configured PHP-FPM socket with:
  - Correct socket path in both NGINX and PHP-FPM configs
  - Proper socket ownership (nginx:nginx)
  - Directory permissions (755)

- **File permissions**: All WordPress files are owned by nginx user with proper read/execute permissions

## Troubleshooting

- **403 Forbidden errors**: SSH into VM and fix permissions with:
  ```
  sudo chmod -R 755 /vagrant/app
  sudo chown -R nginx:nginx /vagrant/app
  sudo setenforce 0  # Disable SELinux
  sudo systemctl restart php-fpm nginx
  ```

- **404 Not Found errors**: Check if WordPress files are present in `app/wordpress` directory
- **Cannot access WordPress**: Check if Vagrant is running with `vagrant status`
- **PHP-FPM socket issues**: Verify the socket exists with `vagrant ssh -c "sudo ls -la /var/run/php-fpm/"`
- **Database connection errors**: Try restarting MariaDB with `vagrant ssh -c "sudo systemctl restart mariadb"`
- **PHP errors**: PHP debug logs are located at `/vagrant/app/wordpress/wp-content/debug.log`
- **NGINX errors**: Check logs with `vagrant ssh -c "sudo cat /var/log/nginx/error.log"` and `vagrant ssh -c "sudo cat /var/log/nginx/wordpress.error.log"`
- **Testing PHP**: Visit http://localhost:8080/test.php to verify PHP is working
- **NGINX configuration**: Verify the configuration with `vagrant ssh -c "sudo nginx -t"`

## Customization

- Edit `provision/bootstrap-wordpress.sh` to modify the VM setup
- Edit `provision/nginx/wordpress.conf` to change NGINX configuration
- Modify `Vagrantfile` to change VM settings (memory, ports, etc.)