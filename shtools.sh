#!/usr/bin/env bash
#
# SHTools - a collection of Linux system administration helpers in one file.
#

SHTOOLS_VERSION="2.1.2"
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

# True if $1 is a valid IPv4 address
valid_ipv4() {
    local IFS=. octet
    local -a octets
    [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    read -ra octets <<< "$1"
    for octet in "${octets[@]}"; do
        (( 10#$octet <= 255 )) || return 1
    done
}

# Used space on / in kilobytes
disk_used_kb() {
    df -Pk / | awk 'NR == 2 {print $3}'
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

show_logo() {
    cat <<'EOF'
   _____ _    _ _______          _         __      _____
  / ____| |  | |__   __|        | |        \ \    / /__ \
 | (___ | |__| |  | | ___   ___ | |___ _____\ \  / /   ) |
  \___ \|  __  |  | |/ _ \ / _ \| / __|______\ \/ /   / /
  ____) | |  | |  | | (_) | (_) | \__ \       \  /   / /_
 |_____/|_|  |_|  |_|\___/ \___/|_|___/        \/   |____|

EOF
}

show_disclaimer() {
    clear
    show_logo
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

system_cleanup() {
    require_apt || return 1
    local before after
    before=$(disk_used_kb)

    info "Removing unused packages..."
    DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y
    info "Cleaning the package cache..."
    apt-get clean

    if command -v journalctl >/dev/null 2>&1; then
        info "$(journalctl --disk-usage 2>/dev/null)"
        if confirm "Remove journal logs older than 7 days?"; then
            journalctl --vacuum-time=7d
        fi
    fi

    after=$(disk_used_kb)
    if (( before > after )); then
        ok "Cleanup complete. Freed $(( (before - after) / 1024 )) MB."
    else
        ok "Cleanup complete."
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

docker_cleanup() {
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed."
        return 1
    fi

    docker system df || return 1
    echo
    info "Stopped containers, unused networks, dangling images and build cache will be removed."

    local args=(-f)
    confirm "Also remove all unused images (not only dangling)?" && args+=(-a)
    if confirm "Also remove unused volumes? (data stored in them will be LOST)"; then
        args+=(--volumes)
    fi
    confirm "Start the cleanup?" || return 0

    docker system prune "${args[@]}" || return 1
    echo
    docker system df
    ok "Docker cleanup complete."
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

# Netplan and ifupdown configs are written for wired interfaces only
is_ethernet() {
    [[ -e "/sys/class/net/$1/device" && ! -e "/sys/class/net/$1/wireless" ]]
}

# Args: interface address/prefix gateway dns...
static_ip_nm() {
    local iface=$1 address=$2 gateway=$3; shift 3
    local con
    con=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null)
    if [[ -z "$con" ]]; then
        error "No NetworkManager connection is active on $iface."
        return 1
    fi
    info "Using NetworkManager (connection: $con)"

    nmcli connection modify "$con" ipv4.method manual ipv4.addresses "$address" \
        ipv4.gateway "$gateway" ipv4.dns "$*" || return 1
    nmcli connection up "$con"
}

static_ip_netplan() {
    local iface=$1 address=$2 gateway=$3; shift 3
    # A file sorted after the existing ones overrides their settings for this interface
    local file="/etc/netplan/99-shtools-$iface.yaml" dns_list
    dns_list=$(printf '%s, ' "$@")
    info "Using netplan ($file)"

    cat > "$file" <<EOF
network:
  version: 2
  ethernets:
    $iface:
      dhcp4: false
      addresses: [$address]
      routes:
        - to: default
          via: $gateway
      nameservers:
        addresses: [${dns_list%, }]
EOF
    chmod 600 "$file"

    if ! netplan generate; then
        error "Invalid netplan configuration, $file has been removed."
        rm -f "$file"
        return 1
    fi
    netplan apply
}

static_ip_ifupdown() {
    local iface=$1 address=$2 gateway=$3; shift 3
    local file tmp stanza
    # The interface may be defined in the main file or in interfaces.d
    file=$(grep -lE "^[[:space:]]*iface[[:space:]]+$iface[[:space:]]+inet[[:space:]]" \
        /etc/network/interfaces /etc/network/interfaces.d/* 2>/dev/null | head -n1)
    file=${file:-/etc/network/interfaces}
    info "Using ifupdown ($file)"

    cp -p "$file" "$file.shtools.bak" 2>/dev/null && info "Backup saved to $file.shtools.bak"

    stanza="iface $iface inet static
    address $address
    gateway $gateway
    dns-nameservers $*"

    tmp=$(mktemp) || return 1
    if grep -qE "^[[:space:]]*iface[[:space:]]+$iface[[:space:]]+inet[[:space:]]" "$file" 2>/dev/null; then
        # Replace the existing stanza and drop its options, keep comments and blank lines
        STANZA="$stanza" awk -v iface="$iface" '
            $1 == "iface" && $2 == iface && $3 == "inet" { print ENVIRON["STANZA"]; skip = 1; next }
            skip && $1 ~ /^(auto|allow-|iface|source|mapping|rename)/ { skip = 0 }
            skip && NF && $1 !~ /^#/ { next }
            { print }
        ' "$file" > "$tmp"
    else
        { cat "$file" 2>/dev/null; printf '\n%s\n' "$stanza"; } > "$tmp"
    fi
    if ! grep -qE "^[[:space:]]*(auto|allow-hotplug)[[:space:]].*\b$iface\b" "$tmp"; then
        printf '\nauto %s\n' "$iface" >> "$tmp"
    fi
    cat "$tmp" > "$file"
    rm -f "$tmp"

    # dns-nameservers needs resolvconf, otherwise write resolv.conf directly
    if ! command -v resolvconf >/dev/null 2>&1 && [[ ! -L /etc/resolv.conf ]]; then
        cp -p /etc/resolv.conf /etc/resolv.conf.shtools.bak 2>/dev/null
        printf 'nameserver %s\n' "$@" > /etc/resolv.conf
    fi

    # Stop the DHCP client, otherwise it keeps renewing the old address
    ifdown --force "$iface" >/dev/null 2>&1
    pkill -f "(dhclient|dhcpcd).*[[:space:]]$iface([[:space:]]|$)"
    ip addr flush dev "$iface"
    ifup "$iface"
}

configure_static_ip() {
    local iface default_iface cur_addr cur_gw address gateway dns_input dns ip_part prefix
    local -a dns_servers

    default_iface=$(ip route show default | awk '{print $5; exit}')
    echo "Network interfaces:"
    ip -br addr show | grep -v '^lo '
    echo

    read -rp "Interface [$default_iface]: " iface
    iface=${iface:-$default_iface}
    if [[ -z "$iface" || ! -e "/sys/class/net/$iface" ]]; then
        error "Interface not found: '$iface'"
        return 1
    fi

    cur_addr=$(ip -4 -o addr show dev "$iface" | awk '{print $4; exit}')
    cur_gw=$(ip route show default dev "$iface" | awk '{print $3; exit}')

    read -rp "IP address with prefix, e.g. 192.168.1.50/24 [$cur_addr]: " address
    address=${address:-$cur_addr}
    ip_part=${address%/*}
    prefix=${address#*/}
    if [[ "$address" != */* ]] || ! valid_ipv4 "$ip_part" \
        || [[ ! "$prefix" =~ ^[0-9]{1,2}$ ]] || (( prefix < 1 || prefix > 32 )); then
        error "Invalid address: '$address' (expected e.g. 192.168.1.50/24)"
        return 1
    fi

    read -rp "Gateway [$cur_gw]: " gateway
    gateway=${gateway:-$cur_gw}
    if ! valid_ipv4 "$gateway"; then
        error "Invalid gateway: '$gateway'"
        return 1
    fi

    read -rp "DNS servers, separated by spaces [1.1.1.1 8.8.8.8]: " dns_input
    read -ra dns_servers <<< "${dns_input//,/ }"
    (( ${#dns_servers[@]} )) || dns_servers=(1.1.1.1 8.8.8.8)
    for dns in "${dns_servers[@]}"; do
        if ! valid_ipv4 "$dns"; then
            error "Invalid DNS server: '$dns'"
            return 1
        fi
    done

    echo
    info "Interface: $iface"
    info "Address:   $address"
    info "Gateway:   $gateway"
    info "DNS:       ${dns_servers[*]}"
    warn "If you are connected over SSH, the connection may drop."
    warn "Reconnect using the new address if it is different from the current one."
    confirm "Apply this configuration?" || return 0

    local rc
    if systemctl is-active --quiet NetworkManager 2>/dev/null \
        && nmcli -t -f DEVICE,STATE device 2>/dev/null | grep -qx "$iface:connected"; then
        static_ip_nm "$iface" "$address" "$gateway" "${dns_servers[@]}"
        rc=$?
    elif ! is_ethernet "$iface"; then
        error "Only wired interfaces are supported outside of NetworkManager."
        return 1
    elif command -v netplan >/dev/null 2>&1 && compgen -G "/etc/netplan/*.yaml" >/dev/null; then
        static_ip_netplan "$iface" "$address" "$gateway" "${dns_servers[@]}"
        rc=$?
    elif command -v ifup >/dev/null 2>&1 && [[ -f /etc/network/interfaces ]]; then
        static_ip_ifupdown "$iface" "$address" "$gateway" "${dns_servers[@]}"
        rc=$?
    else
        error "Unsupported network configuration (NetworkManager, netplan or ifupdown required)."
        return 1
    fi

    sleep 2
    echo
    ip -br addr show dev "$iface"
    ip route show default
    if (( rc == 0 )); then
        ok "Static IP address has been configured."
    else
        error "Failed to apply the configuration. A reboot may help."
        return 1
    fi
}

install_fail2ban() {
    require_systemd || return 1
    apt_refresh || return 1
    apt_install fail2ban || return 1

    # Systems without rsyslog (e.g. Debian 12+) have no auth.log, read the journal instead
    local backend=auto
    if [[ ! -f /var/log/auth.log ]] && command -v journalctl >/dev/null 2>&1; then
        backend=systemd
        apt_install python3-systemd || return 1
    fi

    local jail=/etc/fail2ban/jail.d/shtools-sshd.local
    cat > "$jail" <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
backend = $backend
EOF
    info "Created $jail (ban for 1h after 5 failed attempts in 10m)"

    systemctl enable fail2ban
    systemctl restart fail2ban
    sleep 2
    if fail2ban-client status sshd; then
        ok "Fail2ban is protecting SSH."
    else
        error "Fail2ban did not start correctly. Check: journalctl -u fail2ban"
        return 1
    fi
}

# Read from the DRM subsystem in sysfs, so it works without X11/Wayland
list_video_outputs() {
    local dir card name status enabled mode color
    local -a outputs

    outputs=(/sys/class/drm/card*-*)
    if [[ ! -e "${outputs[0]}" ]]; then
        error "No video outputs found (no DRM driver is loaded)."
        return 1
    fi

    printf '%-6s %-16s %-14s %-9s %s\n' "CARD" "OUTPUT" "STATUS" "ENABLED" "PREFERRED MODE"
    for dir in "${outputs[@]}"; do
        [[ -r "$dir/status" ]] || continue
        name=${dir##*/}
        card=${name%%-*}
        status=$(<"$dir/status")
        enabled=$(cat "$dir/enabled" 2>/dev/null)
        mode=$(head -n1 "$dir/modes" 2>/dev/null)

        case "$status" in
            connected)    color="\e[1;32m" ;;
            disconnected) color="\e[2m" ;;
            *)            color="\e[1;33m" ;;
        esac
        printf "${color}%-6s %-16s %-14s %-9s %s\e[0m\n" \
            "$card" "${name#*-}" "$status" "${enabled:--}" "${mode:--}"
    done
}

# Ubuntu uses custom.conf, Debian uses daemon.conf
gdm_config_file() {
    local file
    for file in /etc/gdm3/custom.conf /etc/gdm3/daemon.conf /etc/gdm/custom.conf; do
        [[ -f "$file" ]] && echo "$file" && return 0
    done
    return 1
}

disable_wayland() {
    local file tmp
    if ! file=$(gdm_config_file); then
        error "GDM configuration not found. This option supports the GDM display manager only."
        return 1
    fi

    if grep -qE '^[[:space:]]*WaylandEnable[[:space:]]*=[[:space:]]*false' "$file"; then
        ok "Wayland is already disabled in $file"
        return 0
    fi

    info "GDM will start the X11 (Xorg) session instead of Wayland ($file)."
    confirm "Disable Wayland?" || return 0

    cp -p "$file" "$file.shtools.bak" && info "Backup saved to $file.shtools.bak"

    # Set WaylandEnable=false in the [daemon] section, replacing an existing
    # (also commented out) entry, and add the section if it is missing
    tmp=$(mktemp) || return 1
    awk '
        /^[[:space:]]*\[/ {
            if (in_daemon && !done) { print "WaylandEnable=false"; done = 1 }
            in_daemon = ($0 ~ /^[[:space:]]*\[daemon\]/)
        }
        in_daemon && /^[[:space:]]*#?[[:space:]]*WaylandEnable[[:space:]]*=/ {
            if (!done) { print "WaylandEnable=false"; done = 1 }
            next
        }
        { print }
        END {
            if (in_daemon && !done) { print "WaylandEnable=false"; done = 1 }
            if (!done) print "\n[daemon]\nWaylandEnable=false"
        }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"

    ok "Wayland has been disabled."
    warn "The change takes effect after a reboot (or a restart of GDM, which ends all graphical sessions)."
    confirm "Reboot the system now?" && reboot
}

# True if apt can install package $1
apt_has_package() {
    [[ -n "$(LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" {print $2}')" ]]
}

show_system_info() {
    local pkg=neofetch

    # fastfetch may have been installed by this option in place of neofetch
    if ! command -v neofetch >/dev/null 2>&1 && command -v fastfetch >/dev/null 2>&1; then
        pkg=fastfetch
    elif ! command -v neofetch >/dev/null 2>&1; then
        warn "neofetch is not installed."
        confirm "Install neofetch?" || return 0
        apt_refresh || return 1
        # neofetch is no longer developed and newer releases (e.g. Debian 13)
        # do not ship it, fastfetch is its successor
        if ! apt_has_package neofetch; then
            if ! apt_has_package fastfetch; then
                error "Neither neofetch nor fastfetch is available in the repositories."
                return 1
            fi
            warn "neofetch is not available in the repositories of $OS_NAME."
            confirm "Install fastfetch (its successor) instead?" || return 0
            pkg=fastfetch
        fi
        apt_install "$pkg" || return 1
        clear
    fi

    "$pkg"
}

reboot_system() {
    confirm "Reboot the system now?" && reboot
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------

# "#Category" adds an entry to the main menu, the "Label|function" entries
# below it are the actions of its submenu
MENU_ITEMS=(
    "#System"
    "System information|show_system_info"
    "System update|system_update"
    "Check for available package updates|check_updates"
    "System cleanup|system_cleanup"
    "Set system time|set_timezone"
    "Change hostname|change_hostname"
    "Change machine ID|change_machine_id"
    "List video outputs|list_video_outputs"
    "Disable Wayland|disable_wayland"
    "Reboot|reboot_system"
    "#Network and security"
    "Configure static IP|configure_static_ip"
    "Install Fail2ban|install_fail2ban"
    "Install net-tools|install_net_tools"
    "#Docker"
    "Install Docker and Docker Compose|install_docker"
    "Configure Docker port|configure_docker_port"
    "Docker cleanup|docker_cleanup"
    "#Web server"
    "Install LAMP stack|install_lamp"
    "Install Apache2 and PHP|install_apache_php"
    "#Packages"
    "Install QEMU Guest Agent|install_qemu_agent"
    "Install unzip|install_unzip"
    "#SHTools"
    "Update SHTools|update_shtools"
)

menu_header() {
    clear
    echo "===== SHTools v$SHTOOLS_VERSION ====="
    echo "System: $OS_NAME"
    echo
    [[ -n "$1" ]] && echo -e "\e[1m$1\e[0m" && echo
}

# Show the actions of one category until the user goes back
display_submenu() {
    local category=$1 choice entry i current=""
    local -a labels actions

    for entry in "${MENU_ITEMS[@]}"; do
        if [[ "$entry" == "#"* ]]; then
            current=${entry#\#}
        elif [[ "$current" == "$category" ]]; then
            labels+=("${entry%%|*}")
            actions+=("${entry##*|}")
        fi
    done

    while true; do
        menu_header "$category"
        for i in "${!labels[@]}"; do
            printf '%2d) %s\n' "$((i + 1))" "${labels[$i]}"
        done
        echo " 0) Back"
        read -rp "Choose an option: " choice

        if [[ "$choice" == "0" ]]; then
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#actions[@]} )); then
            clear
            "${actions[$((choice - 1))]}"
            pause
        else
            error "Invalid choice!"
            sleep 2
        fi
    done
}

display_menu() {
    local choice entry i
    local -a categories

    for entry in "${MENU_ITEMS[@]}"; do
        [[ "$entry" == "#"* ]] && categories+=("${entry#\#}")
    done

    while true; do
        menu_header
        for i in "${!categories[@]}"; do
            printf '%2d) %s\n' "$((i + 1))" "${categories[$i]}"
        done
        echo " 0) Exit"
        read -rp "Choose a category: " choice

        if [[ "$choice" == "0" ]]; then
            exit 0
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#categories[@]} )); then
            display_submenu "${categories[$((choice - 1))]}"
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
