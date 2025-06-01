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
