# Clear the contents of /etc/machine-id (reset the machine ID)
echo -n >/etc/machine-id

# Remove the old D-Bus machine-id file if it exists
rm /var/lib/dbus/machine-id

# Create a symbolic link from /var/lib/dbus/machine-id to /etc/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
