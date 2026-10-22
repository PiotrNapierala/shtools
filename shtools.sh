#!/usr/bin/env bash
#
# SHTools - a collection of Linux system administration helpers in one file.
#

SHTOOLS_VERSION="2.0.0"
SHTOOLS_REPO="PiotrNapierala/shtools"
SHTOOLS_BRANCH="main"
SHTOOLS_RAW_URL="https://raw.githubusercontent.com/$SHTOOLS_REPO/$SHTOOLS_BRANCH/shtools.sh"

SCRIPT_PATH="$(realpath "$0" 2>/dev/null)"

# On Debian "su" (without "-") does not add sbin directories to PATH
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { echo -e "\e[1;34m[INFO]\e[0m $*"; }
ok()    { echo -e "\e[1;32m[ OK ]\e[0m $*"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $*"; }
error() { echo -e "\e[1;31m[FAIL]\e[0m $*" >&2; }

pause() {
    echo
    read -rp "Press Enter to return to menu..."
}

# Ask a yes/no question, returns 0 for yes
confirm() {
    local answer
    read -rp "$1 (y/n): " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}

# Re-run the script with sudo when not started as root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            exec sudo env SHTOOLS_NO_UPDATE_CHECK="$SHTOOLS_NO_UPDATE_CHECK" bash "$0" "$@"
        fi
        error "This script must be run as root (sudo is not installed, use: su -)."
        exit 1
    fi
}

# Read distribution info from /etc/os-release
detect_os() {
    if [[ ! -r /etc/os-release ]]; then
        error "Cannot detect the distribution (/etc/os-release is missing)."
        exit 1
    fi
    # shellcheck disable=SC1091
    OS_ID=$(. /etc/os-release && echo "$ID")
    OS_LIKE=$(. /etc/os-release && echo "$ID_LIKE")
    OS_NAME=$(. /etc/os-release && echo "$PRETTY_NAME")
    OS_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    OS_UBUNTU_CODENAME=$(. /etc/os-release && echo "$UBUNTU_CODENAME")
    OS_DEBIAN_CODENAME=$(. /etc/os-release && echo "$DEBIAN_CODENAME")
}

# True for Debian, Ubuntu and their derivatives (Mint, Pop!_OS, Kali, ...)
is_debian_family() {
    [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" || " $OS_LIKE " == *" debian "* || " $OS_LIKE " == *" ubuntu "* ]]
}

check_os() {
    detect_os
    if ! is_debian_family; then
        warn "$OS_NAME is not a Debian/Ubuntu based distribution."
        warn "Most options in SHTools will not work on this system."
        confirm "Continue anyway?" || exit 0
    fi
}

require_apt() {
    if ! command -v apt-get >/dev/null 2>&1; then
        error "This option requires a Debian/Ubuntu based system (apt)."
        return 1
    fi
}

require_systemd() {
    if [[ ! -d /run/systemd/system ]]; then
        error "This option requires systemd."
        return 1
    fi
}

apt_install() {
    require_apt || return 1
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

apt_refresh() {
    require_apt || return 1
    apt-get update
}

# ---------------------------------------------------------------------------
# Self-update
# ---------------------------------------------------------------------------

# Download a URL to stdout using curl or wget
fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 15 "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- -T 15 "$1"
    else
        error "Neither curl nor wget is installed."
        return 1
    fi
}

# True if version $1 is newer than version $2
version_gt() {
    [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
}

# Download the latest script to a temporary file and print its version.
# Sets REMOTE_FILE and REMOTE_VERSION.
fetch_remote() {
    REMOTE_FILE=$(mktemp) || return 1
    if ! fetch "$SHTOOLS_RAW_URL" > "$REMOTE_FILE"; then
        rm -f "$REMOTE_FILE"
        return 1
    fi

    REMOTE_VERSION=$(grep -m1 '^SHTOOLS_VERSION=' "$REMOTE_FILE" | cut -d'"' -f2)
    # Refuse anything that does not look like a valid SHTools script
    if [[ -z "$REMOTE_VERSION" ]] || ! bash -n "$REMOTE_FILE" 2>/dev/null; then
        rm -f "$REMOTE_FILE"
        return 1
    fi
}

# Replace the running script with the downloaded one and restart it
install_update() {
    if [[ ! -f "$SCRIPT_PATH" || ! -w "$SCRIPT_PATH" ]]; then
        error "Cannot update: SHTools is not running from a writable file."
        info "Download the latest version from https://github.com/$SHTOOLS_REPO"
        rm -f "$REMOTE_FILE"
        return 1
    fi

    # Keep the permissions and owner of the original file
    chmod --reference="$SCRIPT_PATH" "$REMOTE_FILE" 2>/dev/null || chmod 755 "$REMOTE_FILE"
    chown --reference="$SCRIPT_PATH" "$REMOTE_FILE" 2>/dev/null
    if ! mv "$REMOTE_FILE" "$SCRIPT_PATH"; then
        error "Failed to replace $SCRIPT_PATH"
        rm -f "$REMOTE_FILE"
        return 1
    fi

    ok "SHTools updated to version $REMOTE_VERSION. Restarting..."
    sleep 1
    SHTOOLS_RESTARTED=1 exec bash "$SCRIPT_PATH"
}

# Run on every start. Set SHTOOLS_NO_UPDATE_CHECK=1 to skip it.
check_for_update() {
    [[ "$SHTOOLS_NO_UPDATE_CHECK" == "1" ]] && return 0

    info "Checking for a new version..."
    if ! fetch_remote; then
        warn "Could not check for updates. Continuing..."
        return 0
    fi

    if version_gt "$REMOTE_VERSION" "$SHTOOLS_VERSION"; then
        warn "A new version is available: $SHTOOLS_VERSION -> $REMOTE_VERSION"
        if confirm "Update now?"; then
            install_update
        fi
    else
        ok "You have the latest version ($SHTOOLS_VERSION)."
    fi
    rm -f "$REMOTE_FILE"
}

update_shtools() {
    info "Current version: $SHTOOLS_VERSION"
    if ! fetch_remote; then
        error "Could not download the latest version from GitHub."
        return 1
    fi
    info "Latest version:  $REMOTE_VERSION"

    if version_gt "$REMOTE_VERSION" "$SHTOOLS_VERSION"; then
        install_update
    else
        ok "You have the latest version."
        rm -f "$REMOTE_FILE"
    fi
}

# ---------------------------------------------------------------------------
# Disclaimer
# ---------------------------------------------------------------------------

show_disclaimer() {
    clear
    cat <<'EOF'
==================== DISCLAIMER ====================
All .sh scripts available in this repository are provided to simplify and
speed up the execution of repetitive system tasks. They are shared without any
warranties - either express or implied.
You use these scripts at your own risk.
As the author of this repository and the provided scripts:
- I am not responsible for any damage, data loss, system issues, or other
  consequences resulting from the execution of these scripts.
- I provide no guarantee that the scripts are error-free, will function
  correctly in every system configuration, or will be supported in the future.
- I do not take responsibility for any actions taken based on the scripts or
  instructions found in this repository.
Before running any script:
- Carefully review its contents and make sure you understand what it does.
- Test it in a safe, isolated environment whenever possible.
- Back up your system or important data if necessary.
Remember: responsible use of these scripts requires basic knowledge of Linux
system administration.
====================================================
EOF
    echo
    if ! confirm "Do you accept the above disclaimer?"; then
        echo "You did not accept the disclaimer. Exiting."
        exit 0
    fi
}

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

system_update() {
    apt_refresh || return 1
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    if [[ -f /var/run/reboot-required ]]; then
        warn "Reboot required."
    else
        ok "System is up to date."
    fi
}

check_updates() {
    local updates
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq || warn "Could not refresh package lists, the result may be outdated."
        updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
    elif command -v dnf >/dev/null 2>&1; then
        updates=$(dnf check-update --quiet 2>/dev/null | grep -c '^\S')
    elif command -v yum >/dev/null 2>&1; then
        updates=$(yum check-update --quiet 2>/dev/null | grep -c '^\S')
    else
        error "No supported package manager found!"
        return 1
    fi

    if [[ "$updates" -gt 0 ]]; then
        info "Package updates are available ($updates packages)."
    else
        ok "All packages are up to date."
    fi
}

# Docker publishes repositories only for Ubuntu, Debian and Raspbian, so
# derivatives have to use the repository of the distribution they are based on.
# Sets DOCKER_DISTRO and DOCKER_CODENAME.
docker_repo_detect() {
    DOCKER_DISTRO=""
    DOCKER_CODENAME=""

    if [[ "$OS_ID" == "ubuntu" ]]; then
        DOCKER_DISTRO=ubuntu
        DOCKER_CODENAME=$OS_CODENAME
    elif [[ "$OS_ID" == "debian" || "$OS_ID" == "raspbian" ]]; then
        DOCKER_DISTRO=$OS_ID
        DOCKER_CODENAME=$OS_CODENAME
    elif [[ " $OS_LIKE " == *" ubuntu "* ]]; then
        # Linux Mint, Pop!_OS, Zorin OS, elementary OS, ...
        DOCKER_DISTRO=ubuntu
        DOCKER_CODENAME=$OS_UBUNTU_CODENAME
    elif [[ " $OS_LIKE " == *" debian "* ]]; then
        # LMDE, Kali, MX Linux, ...
        DOCKER_DISTRO=debian
        DOCKER_CODENAME=$OS_DEBIAN_CODENAME
        if [[ -z "$DOCKER_CODENAME" ]]; then
            case "$OS_ID" in
                kali) DOCKER_CODENAME=bookworm ;;  # recommended by Docker docs
                *)
                    case "$(cut -d. -f1 /etc/debian_version 2>/dev/null)" in
                        11) DOCKER_CODENAME=bullseye ;;
                        12) DOCKER_CODENAME=bookworm ;;
                        13) DOCKER_CODENAME=trixie ;;
                    esac
                    ;;
            esac
        fi
    fi

    if [[ -z "$DOCKER_DISTRO" || -z "$DOCKER_CODENAME" ]]; then
        error "Cannot determine the Docker repository for $OS_NAME."
        return 1
    fi

    if ! curl -fsI "https://download.docker.com/linux/$DOCKER_DISTRO/dists/$DOCKER_CODENAME/Release" >/dev/null; then
        error "Docker does not provide packages for $DOCKER_DISTRO $DOCKER_CODENAME."
        return 1
    fi
    info "Using Docker repository: $DOCKER_DISTRO $DOCKER_CODENAME"
}

install_docker() {
    require_apt || return 1

    apt_refresh
    apt_install ca-certificates curl gnupg || return 1
    docker_repo_detect || return 1

    local distro=$DOCKER_DISTRO codename=$DOCKER_CODENAME

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$distro/gpg" \
        | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg || return 1
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$distro $codename stable" \
        > /etc/apt/sources.list.d/docker.list

    apt_refresh
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || return 1

    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]] && confirm "Add user '$SUDO_USER' to the docker group?"; then
        usermod -aG docker "$SUDO_USER"
        info "Log out and back in for the group change to take effect."
    fi

    ok "Docker installed: $(docker --version)"
    ok "Compose installed: $(docker compose version)"
}

configure_docker_port() {
    require_systemd || return 1
    if ! command -v dockerd >/dev/null 2>&1; then
        error "Docker is not installed."
        return 1
    fi

    local ip_addr port=2375
    ip_addr=$(hostname -I | awk '{print $1}')

    warn "This exposes the Docker API on tcp://$ip_addr:$port WITHOUT TLS or authentication."
    warn "Anyone who can reach this port gets full root access to this host."
    confirm "Do you want to continue?" || return 0

    # A drop-in override survives Docker package upgrades
    local override_dir=/etc/systemd/system/docker.service.d
    mkdir -p "$override_dir"
    cat > "$override_dir/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://$ip_addr:$port --containerd=/run/containerd/containerd.sock
EOF
    info "Created $override_dir/override.conf"

    systemctl daemon-reload
    systemctl restart docker.service

    sleep 2
    if ss -lnt | grep -q ":$port "; then
        ok "Docker is listening on $ip_addr:$port"
    else
        error "Docker is not listening on port $port. Check: journalctl -u docker"
        return 1
    fi
}

install_lamp() {
    apt_refresh || return 1
    # default-mysql-server is MySQL on Ubuntu and MariaDB on Debian
    apt_install apache2 default-mysql-server php libapache2-mod-php php-mysql || return 1

    local secure_cmd
    secure_cmd=$(command -v mariadb-secure-installation || command -v mysql_secure_installation)
    if [[ -n "$secure_cmd" ]] && confirm "Run $(basename "$secure_cmd") now?"; then
        "$secure_cmd"
    fi

    systemctl enable apache2
    systemctl restart apache2
    ok "LAMP server has been installed."
}

install_apache_php() {
    apt_refresh || return 1
    apt_install apache2 php libapache2-mod-php php-cli php-mbstring php-xml php-curl php-mysql || return 1

    systemctl enable apache2
    systemctl restart apache2

    ok "Installation complete!"
    echo "To test PHP, create an info.php file in /var/www/html/:"
    echo "echo '<?php phpinfo(); ?>' > /var/www/html/info.php"
    echo "Then open your browser and go to: http://localhost/info.php"
}

install_net_tools() {
    apt_refresh || return 1
    apt_install net-tools || return 1
    ifconfig
}

install_qemu_agent() {
    apt_refresh || return 1
    apt_install qemu-guest-agent || return 1
    systemctl enable --now qemu-guest-agent
    ok "QEMU Guest Agent installed and started."
}

install_unzip() {
    apt_refresh || return 1
    apt_install unzip || return 1
    ok "unzip installed."
}

set_timezone() {
    require_systemd || return 1
    local timezone
    echo "Current timezone: $(timedatectl show -p Timezone --value)"
    read -rp "Enter your desired timezone (e.g., Europe/Warsaw): " timezone

    if ! timedatectl list-timezones | grep -qx "$timezone"; then
        error "Invalid timezone: '$timezone'"
        if [[ -n "$timezone" ]]; then
            echo "Matching timezones:"
            timedatectl list-timezones | grep -i -- "$timezone" | head -20
        fi
        return 1
    fi

    timedatectl set-timezone "$timezone"
    timedatectl set-ntp true
    timedatectl
    ok "Time and timezone have been set."
}

change_machine_id() {
    require_systemd || return 1
    warn "This generates a new machine ID (use it on cloned VMs)."
    confirm "Do you want to continue?" || return 0

    rm -f /etc/machine-id /var/lib/dbus/machine-id
    systemd-machine-id-setup
    mkdir -p /var/lib/dbus
    ln -sf /etc/machine-id /var/lib/dbus/machine-id

    ok "New machine ID: $(cat /etc/machine-id)"
    info "A reboot is recommended."
}

change_hostname() {
    require_systemd || return 1
    local old_hostname new_hostname
    old_hostname=$(hostname)
    echo "Current hostname: $old_hostname"
    read -rp "Enter new hostname: " new_hostname

    if [[ -z "$new_hostname" ]]; then
        error "No hostname provided."
        return 1
    fi
    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        error "Invalid hostname: letters, digits and '-' only, max 63 characters."
        return 1
    fi

    hostnamectl set-hostname "$new_hostname"

    # Replace the old name as a whole word only, or add an entry if missing
    if grep -qw -- "$old_hostname" /etc/hosts; then
        sed -i "s/\b$old_hostname\b/$new_hostname/g" /etc/hosts
    else
        echo -e "127.0.1.1\t$new_hostname" >> /etc/hosts
    fi

    ok "Hostname has been changed to: $new_hostname"
}

reboot_system() {
    confirm "Reboot the system now?" && reboot
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------

# Each entry: "Label|function"
MENU_ITEMS=(
    "System update|system_update"
    "Check for available package updates|check_updates"
    "Install Docker and Docker Compose|install_docker"
    "Configure Docker port|configure_docker_port"
    "Install LAMP stack|install_lamp"
    "Install Apache2 and PHP|install_apache_php"
    "Install net-tools|install_net_tools"
    "Install QEMU Guest Agent|install_qemu_agent"
    "Install unzip|install_unzip"
    "Set system time|set_timezone"
    "Change machine ID|change_machine_id"
    "Change hostname|change_hostname"
    "Reboot|reboot_system"
    "Update SHTools|update_shtools"
)

display_menu() {
    local choice i count=${#MENU_ITEMS[@]}

    while true; do
        clear
        echo "===== SHTools v$SHTOOLS_VERSION ====="
        echo "System: $OS_NAME"
        echo
        for i in "${!MENU_ITEMS[@]}"; do
            echo "$((i + 1))) ${MENU_ITEMS[$i]%%|*}"
        done
        echo "0) Exit"
        read -rp "Choose an option: " choice

        if [[ "$choice" == "0" ]]; then
            exit 0
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            clear
            "${MENU_ITEMS[$((choice - 1))]##*|}"
            pause
        else
            error "Invalid choice!"
            sleep 2
        fi
    done
}

main() {
    require_root "$@"
    # After a self-update the disclaimer was already accepted
    if [[ "$SHTOOLS_RESTARTED" != "1" ]]; then
        show_disclaimer
        check_os
        check_for_update
    else
        detect_os
    fi
    display_menu
}

main "$@"
