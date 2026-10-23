# SHTools
![Version](https://img.shields.io/badge/Version-2.1.1-green)
![GitHub](https://img.shields.io/badge/GitHub-PiotrNapierala%2Fshtools-blue?link=https%3A%2F%2Fgithub.com%2FPiotrNapierala%2Fshtools)
![License](https://img.shields.io/badge/License-GPL--3.0-orange)

## What is SHTools?
SHTools is a single Bash script with a user-friendly menu designed to help you quickly configure Debian and Ubuntu based Linux systems.

All tools live in one file, `shtools.sh`. Nothing else is downloaded while it runs, except for the update check and packages installed by the options you choose.

## Supported systems
- Debian
- Ubuntu
- Derivatives of Debian and Ubuntu, e.g. Linux Mint, LMDE, Pop!_OS, Zorin OS, elementary OS, Kali Linux, MX Linux

Distribution detection is based on `/etc/os-release`. Options that manage system settings (time, hostname, machine ID, Docker port, Fail2ban) require systemd.

## Installation
Download the script:
```bash
curl -fsSLO https://raw.githubusercontent.com/PiotrNapierala/shtools/main/shtools.sh
```
or, if `curl` is not installed:
```bash
wget https://raw.githubusercontent.com/PiotrNapierala/shtools/main/shtools.sh
```

Run it:
```bash
sudo bash shtools.sh
```
SHTools needs root privileges. If started as a regular user, it restarts itself with `sudo`. On systems without `sudo` (e.g. a minimal Debian install), run it as root with `su -`.

## Updates
On every start SHTools checks GitHub for a newer version. When one is available, it asks whether to update. After updating, the script replaces itself and restarts.

You can also update at any time with the **Update SHTools** option in the **SHTools** menu.

To skip the update check at startup (e.g. on a machine without internet access):
```bash
sudo env SHTOOLS_NO_UPDATE_CHECK=1 bash shtools.sh
```

## Features

### System

| Option | Description |
|---|---|
| System update | Refreshes package lists, upgrades all packages and reports if a reboot is required |
| Check for available package updates | Shows the number of packages that can be upgraded (apt, dnf, yum) |
| System cleanup | Removes unused packages (`apt autoremove --purge`), cleans the package cache and optionally removes journal logs older than 7 days. Shows the freed disk space |
| Set system time | Sets the timezone and enables NTP time synchronization |
| Change hostname | Changes the hostname and updates `/etc/hosts` |
| Change machine ID | Generates a new `/etc/machine-id` (useful for cloned virtual machines) |
| Reboot | Reboots the system after confirmation |

### Network and security

| Option | Description |
|---|---|
| Configure static IP | Sets a static IPv4 address, gateway and DNS servers for the chosen interface. Uses NetworkManager, netplan (`/etc/netplan/99-shtools-<interface>.yaml`) or ifupdown (`/etc/network/interfaces`, with a backup), depending on the system |
| Install Fail2ban | Installs Fail2ban and enables the SSH jail (`/etc/fail2ban/jail.d/shtools-sshd.local`): 1 hour ban after 5 failed attempts within 10 minutes |
| Install net-tools | Installs `net-tools` and shows the output of `ifconfig` |

### Docker

| Option | Description |
|---|---|
| Install Docker and Docker Compose | Adds the official Docker repository (Ubuntu or Debian, also for derivatives) and installs Docker Engine with the Buildx and Compose plugins. Optionally adds your user to the `docker` group |
| Configure Docker port | Exposes the Docker API on `tcp://<host IP>:2375` using a systemd drop-in (`/etc/systemd/system/docker.service.d/override.conf`) |
| Docker cleanup | Removes stopped containers, unused networks, dangling images and build cache. Optionally also all unused images and volumes |

### Web server

| Option | Description |
|---|---|
| Install LAMP stack | Installs Apache2, MySQL (Ubuntu) or MariaDB (Debian) and PHP. Optionally runs the secure installation wizard |
| Install Apache2 and PHP | Installs Apache2 and PHP with common modules (cli, mbstring, xml, curl, mysql) |

### Packages

| Option | Description |
|---|---|
| Install QEMU Guest Agent | Installs and starts `qemu-guest-agent` (for Proxmox and other QEMU/KVM virtual machines) |
| Install unzip | Installs `unzip` |

### SHTools

| Option | Description |
|---|---|
| Update SHTools | Updates SHTools to the latest version from GitHub |

> **Warning:** *Configure Docker port* exposes the Docker API without TLS or authentication. Anyone who can reach this port gets full root access to the host. Use it only in trusted, isolated networks.

## Adding a new option
1. Add a function in the *Tools* section of `shtools.sh`.
2. Add an entry to the `MENU_ITEMS` array in the format `"Label|function_name"`, under the right category. Entries in the format `"#Category name"` are shown in the main menu, and the actions below them form its submenu. Menu numbers are assigned automatically.

Helper functions available in the script:
- `info`, `ok`, `warn`, `error` – colored messages
- `confirm "Question?"` – yes/no prompt
- `apt_refresh`, `apt_install <packages>` – non-interactive package installation
- `require_apt`, `require_systemd` – check requirements before running an option

When releasing a new version, increase `SHTOOLS_VERSION` in `shtools.sh` – the update check compares this value with the version on GitHub.

## Disclaimer
These scripts are provided to simplify and speed up the execution of repetitive system tasks. They are shared without any warranties – either express or implied. You use them at your own risk.

Before running SHTools:
- Carefully review its contents and make sure you understand what it does.
- Test it in a safe, isolated environment whenever possible.
- Back up your system or important data if necessary.

## License
SHTools is licensed under the GPL-3.0 license – see the [LICENSE](LICENSE) file for details.
