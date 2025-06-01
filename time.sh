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
