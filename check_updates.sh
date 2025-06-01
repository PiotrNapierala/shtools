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
