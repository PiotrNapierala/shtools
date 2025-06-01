# SHTools
![Static Badge](https://img.shields.io/badge/Version-1.5-green)
![Static Badge](https://img.shields.io/badge/Website-https%3A%2F%2Fshtools.pnapierala.pl-blue?link=https%3A%2F%2Fshtools.pnapierala.pl)
![Static Badge](https://img.shields.io/badge/License-GPL--3.0-orange)


## What is SHTools?
SHTools is a collection of SH scripts with a user-friendly menu designed to help you quickly configure Debian-based Linux systems.

## Installation
The tool does not require any installer. All you need to do is download the menu.sh file using this command:
```bash
wget https://shtools.pnapierala.pl/download/menu.sh
```
After downloading, you can run the script using this command:
```bash
sudo bash menu.sh
```
Download and run in one line:
```bash
wget https://shtools.pnapierala.pl/download/menu.sh && chmod +x menu.sh && bash menu.sh
```

## Docs

### menu.sh

The `menu.sh` file is responsible for launching individual scripts and ensuring they are always up to date. Remember that the latest versions of the scripts are always available on my website. The file is designed to display a usage disclaimer and download the current script list from the server. Scripts are downloaded only for the duration of their execution.

```bash
#!/bin/bash

SCRIPT_VERSION="1.5"
VERSION_URL="https://shtools.pnapierala.pl/download/version.txt"
SCRIPT_URL="https://shtools.pnapierala.pl/download/menu.sh"
MENU_ITEMS_URL="https://shtools.pnapierala.pl/download/menu_items.txt"

SCRIPT_PATH="$(realpath "$0")"

# Show disclaimer and require user acceptance before continuing
show_disclaimer() {
    clear
    echo "==================== DISCLAIMER ===================="
    echo "All .sh scripts available on this website are provided to simplify and speed up the execution of repetitive system tasks. They are shared without any warranties – either express or implied."
    echo "You use these scripts at your own risk."
    echo "As the author of this website and the provided scripts:"
    echo "- I am not responsible for any damage, data loss, system issues, or other consequences resulting from the execution of these scripts."
    echo "- I provide no guarantee that the scripts are error-free, will function correctly in every system configuration, or will be supported in the future."
    echo "- I do not take responsibility for any actions taken based on the scripts or instructions found on this website."
    echo "Before running any script:"
    echo "- Carefully review its contents and make sure you understand what it does."
    echo "- Test it in a safe, isolated environment whenever possible."
    echo "- Back up your system or important data if necessary."
    echo "Remember: responsible use of these scripts requires basic knowledge of Linux system administration."
    echo "===================================================="
    echo
    read -p "Do you accept the above disclaimer? (y/n): " accept
    if [[ "$accept" != "y" && "$accept" != "Y" ]]; then
        echo "You did not accept the disclaimer. Exiting."
        exit 0
    fi
}

# Function to check for script updates
check_for_update() {
    echo "Checking for new version..."
    NEW_VERSION=$(wget -qO- "$VERSION_URL")
    
    if [[ -z "$NEW_VERSION" ]]; then
        echo "Failed to fetch version info. Continuing..."
        return
    fi
    
    echo "Current version: $SCRIPT_VERSION"
    echo "Available version: $NEW_VERSION"
    
    if [[ "$NEW_VERSION" > "$SCRIPT_VERSION" ]]; then
        echo "A new version is available! Downloading..."
        wget -O "$SCRIPT_PATH.new" "$SCRIPT_URL" --no-check-certificate
        
        if [[ $? -eq 0 ]]; then
            chmod +x "$SCRIPT_PATH.new"
            mv "$SCRIPT_PATH.new" "$SCRIPT_PATH"
            echo "Script updated to version $NEW_VERSION."
            echo "Press any key to continue..."
            read -n 1 -s
            echo "Restarting..."
            exec "$SCRIPT_PATH"
        else
            echo "Error downloading new version!"
            rm -f "$SCRIPT_PATH.new"
        fi
    else
        echo "You have the latest version."
    fi
}

SCRIPT_DIR="$(dirname "$SCRIPT_PATH")/shtools_scripts"
mkdir -p "$SCRIPT_DIR"

# Function to fetch menu items from remote server
fetch_menu_items() {
    wget -qO "$SCRIPT_DIR/menu_items.txt" "$MENU_ITEMS_URL"
    
    if [[ ! -s "$SCRIPT_DIR/menu_items.txt" ]]; then
        echo "Error: downloaded menu_items.txt is empty!"
        exit 1
    fi

    # Clean up any unwanted characters at the end of lines
    sed -i 's/[\"$]$//' "$SCRIPT_DIR/menu_items.txt"
}

# Function to display the menu and handle user input
display_menu() {
    clear
    echo "===== MENU ====="
    local i=1
    declare -A menu_items

    # Read menu items from file and display them
    while IFS=':' read -r name script; do
        name=$(echo "$name" | tr -d '"')
        script=$(echo "$script" | tr -d '"$')

        if [[ -n "$name" && -n "$script" ]]; then
            menu_items[$i]="$script"
            echo "$i) $name"
            ((i++))
        fi
    done < "$SCRIPT_DIR/menu_items.txt"

    if [[ ${#menu_items[@]} -eq 0 ]]; then
        echo "No options available in menu_items.txt!"
    fi

    echo "$i) Exit"
    read -p "Choose an option: " choice

    if [[ $choice -eq $i ]]; then
        exit 0
    elif [[ -n "${menu_items[$choice]}" ]]; then
        run_script "${menu_items[$choice]}"
    else
        echo "Invalid choice!"
        sleep 2
        display_menu
    fi
}

# Function to download and run a selected script
run_script() {
    local script_name="$1"
    local script_url="https://shtools.pnapierala.pl/download/$script_name"
    local script_path="$SCRIPT_DIR/$script_name"
    
    wget -O "$script_path" "$script_url" --no-check-certificate
    chmod +x "$script_path"
    
    "$script_path"
    rm -f "$script_path"
    
    read -p "Press Enter to return to menu..."
    display_menu
}

show_disclaimer

check_for_update

fetch_menu_items

display_menu
```

### update.sh
```bash
#!/bin/bash

# Update the package list using apt
apt update

# Update the package list using apt-get (for compatibility)
apt-get update

# Upgrade all installed packages to the latest version
apt upgrade -y

# Check if a system reboot is required after the upgrade
if [ -f /var/run/reboot-required ]; then
  echo 'Reboot required'
fi
```

### docker.sh
```bash
#!/bin/bash

# Update the package list to get the latest information about available packages
sudo apt update

# Install required packages for Docker installation: CA certificates, curl, gnupg, and lsb-release
sudo apt install -y ca-certificates curl gnupg lsb-release

# Create the directory for Docker's GPG keyring if it doesn't exist
sudo mkdir -p /etc/apt/keyrings

# Download Docker's official GPG key and save it to the keyring
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker's official repository to APT sources using the downloaded GPG key for verification
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the package list again to include Docker packages from the new repository
sudo apt update

# Install Docker Engine, CLI, containerd, and Docker Compose plugin
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Download the standalone Docker Compose binary from GitHub
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make the Docker Compose binary executable
sudo chmod +x /usr/local/bin/docker-compose
```

### ip.sh
```bash
# Update the package list using apt
sudo apt update

# Update the package list using apt-get (redundant, but included for compatibility)
sudo apt-get update

# Install the net-tools package, which provides the ifconfig command
sudo apt-get install net-tools

# Display network interface configuration using ifconfig
ifconfig
```

### lamp.sh
```bash
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
```

### qemu.sh
```bash
# Update the package list using apt
sudo apt update

# Update the package list using apt-get (for compatibility)
sudo apt-get update

# Install the qemu-guest-agent package
sudo apt-get install qemu-guest-agent -y

# Enable the qemu-guest-agent service to start on boot
sudo systemctl enable qemu-guest-agent
```

### docker_port.sh
```bash
#!/bin/bash

# Get the first IP address of the host
IP_ADDR=$(hostname -I | awk '{print $1}')

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Stop Docker service
echo "Stopping Docker service..."
systemctl stop docker

# Stop Docker socket
echo "Stopping Docker socket..."
systemctl stop docker.socket

CONFIG_FILE="/usr/lib/systemd/system/docker.service"
# Modify the Docker service file to listen on TCP port 2375
echo "Modifying $CONFIG_FILE..."
sed -i.bak "s|^ExecStart=.*|ExecStart=/usr/bin/dockerd -H fd:// -H tcp://$IP_ADDR:2375|" "$CONFIG_FILE"

# Inform about backup creation
echo "Backup created as $CONFIG_FILE.bak"

# Reload systemd configuration to apply changes
echo "Reloading systemd configuration..."
systemctl daemon-reload

# Restart Docker service
echo "Restarting Docker..."
systemctl restart docker.service

# Check if Docker is listening on port 2375
echo "Checking if Docker is listening on port 2375..."
netstat -lntp | grep dockerd
```

### check_updates.sh
```bash
#!/bin/sh

# Check which package manager is available: apt, dnf, or yum
if command -v apt > /dev/null 2>&1; then
    MANAGER="apt"
elif command -v dnf > /dev/null 2>&1; then
    MANAGER="dnf"
elif command -v yum > /dev/null 2>&1; then
    MANAGER="yum"
else
    # Print an error message if no supported package manager is found and exit
    echo "No supported package manager found!"
    exit 1
fi

# Count the number of available package updates depending on the package manager
if [ "$MANAGER" = "apt" ]; then
    # For apt: list upgradable packages and count lines containing "upgradable"
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
elif [ "$MANAGER" = "dnf" ]; then
    # For dnf: check for updates and count non-empty lines (each update is a line)
    UPDATES=$(dnf check-update --quiet | grep -c "^\S")
elif [ "$MANAGER" = "yum" ]; then
    # For yum: check for updates and count non-empty lines (each update is a line)
    UPDATES=$(yum check-update --quiet | grep -c "^\S")
fi

# Print the result: if updates are available, show the count; otherwise, say packages are up to date
if [ "$UPDATES" -gt 0 ]; then
    echo "Package updates are available ($UPDATES packages)."
else
    echo "All packages are up to date."
fi
```

### hostname.sh
```bash
#!/bin/bash

# Prompt user for new hostname
read -p "Enter new hostname: " NEW_HOSTNAME

# Check if hostname was provided
if [[ -z "$NEW_HOSTNAME" ]]; then
    echo "No hostname provided. Exiting."
    exit 1
fi

# Set the new hostname using hostnamectl
sudo hostnamectl set-hostname "$NEW_HOSTNAME"

# Update /etc/hosts with the new hostname
CURRENT_HOSTNAME=$(hostname)
sudo sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts

# Inform the user about the change
echo "Hostname has been changed to: $NEW_HOSTNAME"
```

### install_apache_php.sh
```bash
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
```

### machineid.sh
```bash
# Clear the contents of /etc/machine-id (reset the machine ID)
echo -n >/etc/machine-id

# Remove the old D-Bus machine-id file if it exists
rm /var/lib/dbus/machine-id

# Create a symbolic link from /var/lib/dbus/machine-id to /etc/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
```

### reboot.sh
```bash
sudo reboot now
```
Just a regular reboot ;)

### time.sh
```bash
#!/bin/bash

# List available timezones and prompt the user to select one
echo "Available timezones (partial list):"
timedatectl list-timezones | grep -E 'Europe|America|Asia|Africa|Australia' | nl -w2 -s'. '

echo
read -p "Enter your desired timezone (e.g., Europe/Warsaw): " TIMEZONE

# Check if the entered timezone is valid
if ! timedatectl list-timezones | grep -qx "$TIMEZONE"; then
    echo "Invalid timezone. Please run the script again and enter a valid timezone."
    exit 1
fi

# Set the selected timezone
echo "Setting timezone to $TIMEZONE..."
sudo timedatectl set-timezone "$TIMEZONE"

# Enable NTP time synchronization
echo "Enabling time synchronization..."
sudo timedatectl set-ntp true

# Show current time and timezone settings
timedatectl

# Inform the user that the operation is complete
echo "Time and timezone have been set."
```

### unzip.sh
```bash
# Update the package list using apt
sudo apt update

# Update the package list using apt-get (for compatibility)
sudo apt-get update

# Install the unzip package
sudo apt-get install unzip
```

