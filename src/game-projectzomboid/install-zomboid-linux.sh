#!/bin/bash
#
# Install script for Project Zomboid
#
# Please ensure to run this script as root (or at least with sudo)
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell - cdp1337@veraciousnetwork.com
#
# Supports:
#   Debian 12
#   Ubuntu 24.04
#
# Requirements:
#   None
#
# TRMM Custom Fields:
#   None

############################################
## Parameter Configuration
############################################

GAME="Zomboid"
GAME_USER="steam"
GAME_DIR="/home/$GAME_USER/$GAME"
STEAM_DIR="/home/$GAME_USER/.local/share/Steam"

# scriptlet:steam/install-steamcmd.sh
# scriptlet:_common/print_header.sh
# scriptlet:_common/get_firewall.sh
# scriptlet:_common/firewall_allow.sh
# scriptlet:ufw/install.sh

if [ "$(whoami)" != "root" ]; then
	echo "Please run this script as root!" >&2
	exit 1
fi

print_header 'Project Zomboid Installer'

if [ -z "$(getent passwd $GAME_USER)" ]; then
	useradd -m -U $GAME_USER
fi

if [ "$(get_enabled_firewall)" == "none" ]; then
	install_ufw
fi

# Install steam binary and steamcmd
install_steamcmd

sudo -u $GAME_USER /usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 380870 validate +quit
if [ $? -ne 0 ]; then
	echo "Could not install Project Zomboid Server, exiting" >&2
	exit 1
fi

# Install system service file to be loaded by systemd
cat > /etc/systemd/system/zomboid.service <<EOF
[Unit]
# DYNAMICALLY GENERATED FILE! Edit at your own risk
Description=Project Zomboid Dedicated Server
After=network.target

[Service]
Type=simple
LimitNOFILE=10000
User=$GAME_USER
Group=$GAME_USER
WorkingDirectory=$GAME_DIR/AppFiles
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u $GAME_USER)
Environment="STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_DIR"
PreExecStart=/usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 380870 validate +quit
ExecStart=$GAME_DIR/AppFiles/start-server.sh
Restart=on-failure
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable zomboid


if [ ! -e "$GAME_DIR/Server/servertest.ini" ]; then
	printheader "First Run Setup"
	echo 'Zomboid will run initially and generate the server configuration files.'
	echo 'You will be asked for the password for the admin user.'
	echo ''
	echo 'When set, type "quit" to exit the server and finish setup.'
	echo 'Press [ENTER] to continue'
	read TRASH

	sudo -u $GAME_USER $GAME_DIR/AppFiles/start-server.sh
fi


firewall_allow --port "16261:16262" --udp


print_header 'Project Zomboid Installation Complete'
echo 'Game server will auto-update on restarts and will auto-start on server boot.'
echo ''
echo "To restart:     sudo systemctl restart zomboid"
echo "To start:       sudo systemctl start zomboid"
echo "To stop:        sudo systemctl stop zomboid"
echo "Game files:     $GAME_DIR/AppFiles/"
echo "Game log:       $GAME_DIR/server-console.txt"
echo "Game settings:  $GAME_DIR/Server/servertest.ini"
