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
