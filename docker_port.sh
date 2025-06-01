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
