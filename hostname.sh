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
