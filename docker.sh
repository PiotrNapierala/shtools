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
