# Update the package list using apt
sudo apt update

# Update the package list using apt-get (for compatibility)
sudo apt-get update

# Install the qemu-guest-agent package
sudo apt-get install qemu-guest-agent -y

# Enable the qemu-guest-agent service to start on boot
sudo systemctl enable qemu-guest-agent
