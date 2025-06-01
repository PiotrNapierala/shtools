#!/bin/bash

# Update package list
sudo apt update -y

# Install Apache2 web server
sudo apt install -y apache2

# Install MySQL server and run secure installation
sudo apt install -y mysql-server
sudo mysql_secure_installation

# Install PHP and required modules for Apache and MySQL
sudo apt install -y php libapache2-mod-php php-mysql

# Restart Apache2 to load PHP module
sudo systemctl restart apache2

# Inform the user that LAMP server is installed
echo "LAMP server has been installed."
