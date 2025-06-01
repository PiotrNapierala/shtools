#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root or use sudo."
    exit 1
fi

# Update package list
echo "Updating package list..."
apt update -y

# Install Apache2 web server
echo "Installing Apache2..."
apt install -y apache2

# Install PHP and required modules
echo "Installing PHP and required modules..."
apt install -y php libapache2-mod-php php-cli php-mbstring php-xml php-curl php-mysql

# Restart Apache2 to load PHP module
echo "Restarting Apache2..."
systemctl restart apache2

# Enable Apache2 to start on boot
echo "Enabling Apache2 to start on boot..."
systemctl enable apache2

# Installation complete, provide instructions for testing PHP
echo "Installation complete!"
echo "To test PHP, create an info.php file in /var/www/html/:"
echo "echo '<?php phpinfo(); ?>' > /var/www/html/info.php"
echo "Then open your browser and go to: http://localhost/info.php"

exit 0
