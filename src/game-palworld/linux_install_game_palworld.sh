#!/bin/bash
#
# Install Palworld
#
# Please ensure to run this script as root (or at least with sudo)
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com> 
# @AUTHOR  Drew Wort <drew@worttechnologies.tech>
# @CATEGORY Game Server
# @TRMM-TIMEOUT 600
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

GAME="Palworld"
GAME_USER="steam"
GAME_DIR="/home/$GAME_USER/$GAME"
STEAM_DIR="/home/$GAME_USER/.local/share/Steam"
THREADS="$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | wc -l)"
# scriptlet:steam/install-steamcmd.sh
# scriptlet:_common/print_header.sh
# scriptlet:_common/get_firewall.sh
# scriptlet:_common/firewall_allow.sh
# scriptlet:ufw/install.sh
# scriptlet:_common/prompt_text.sh

if [ "$(whoami)" != "root" ]; then
	echo "Please run this script as root!" >&2
	exit 1
fi

print_header 'Palworld Installer'

if [ -z "$(getent passwd $GAME_USER)" ]; then
	useradd -m -U $GAME_USER
fi

if [ "$(get_enabled_firewall)" == "none" ]; then
	install_ufw
fi

# Install steam binary and steamcmd
install_steamcmd

sudo -u $GAME_USER /usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 2394010 validate +quit
if [ $? -ne 0 ]; then
	echo "Could not install Palworld Server, exiting" >&2
	exit 1
fi

# Install system service file to be loaded by systemd
cat > /etc/systemd/system/palworld.service <<EOF
[Unit]
# DYNAMICALLY GENERATED FILE! Edit at your own risk
Description=Palworld Dedicated Server
After=network.target

[Service]
Type=simple
LimitNOFILE=10000
User=$GAME_USER
Group=$GAME_USER
WorkingDirectory=$GAME_DIR/AppFiles
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u $GAME_USER)
Environment="STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_DIR"
PreExecStart=/usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 2394010 validate +quit
ExecStart=$GAME_DIR/AppFiles/PalServer.sh -publiclobby -useperfthreads -NoAsyncLoadingThread -UseMuilthreadForDS -NumberOfWorkerThreadsServer=$THREADS
Restart=on-failure
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable palworld



if [ ! -e "$GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini" ]; then
	printheader "First Run Setup"
	echo 'Palworld will run initially and generate the server configuration files.'
	systemctl start palworld 
	sleep 30
	systemctl stop palworld
	sudo -u $GAME_USER cp $GAME_DIR/AppFiles/DefaultPalWorldSettings.ini $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
fi
#Initial configuration settings for the user
	# Loads the Curret Variables from the config File 
ServerName="$(cat $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini | egrep '^OptionSettings=' | sed 's:.*ServerName="\([^"]*\)".*:\1:')"
ServerDescription="$(cat $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini | egrep '^OptionSettings=' | sed 's:.*ServerDescription="\([^"]*\)".*:\1:')"
ServerPassword="$(cat $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini | egrep '^OptionSettings=' | sed 's:.*ServerPassword="\([^"]*\)".*:\1:')"
AdminPassword="$(cat $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini | egrep '^OptionSettings=' | sed 's:.*AdmiPassword="\([^"]*\)".*:\1:')"
	# Replaces the Default variables above with User Collected Variables
ServerName="$(prompt_text 'Please Enter the Desired Server Name Leave Blank to skip changing' --default="$ServerName")" 
ServerDescription="$(prompt_text 'Please Enter the Desired Server Description' --default="$ServerDescription")" 
ServerPassword="$(prompt_text 'Please Enter the Desired Server Password (Used for any client to connect leave blank previous password)' --default="$ServerPassword")"
AdminPassword="$(prompt_text 'Please Enter the Desired Administrator Password (used for in game admin functions default password is admin)' --default="$AdminPassword")" 
	# Actually inserting the new variables into the config file 
sudo -u $GAME_USER sed -i "s:ServerName=[^,]*:ServerName=\"$ServerName\":" $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
sudo -u $GAME_USER sed -i "s:ServerDescription=[^,]*:ServerDescription=\"$ServerDescription\":" $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
sudo -u $GAME_USER sed -i "s:ServerPassword=[^,]*:ServerPassword=\"$ServerPassword\":" $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
sudo -u $GAME_USER sed -i "s:AdminPassword=[^,]*:AdminPassword=\"$AdminPassword\":" $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

# Create some helpful links for the user.
[ -h "$GAME_DIR/PalWorldSettings.ini" ] || sudo -u steam ln -s $GAME_DIR/AppFiles/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini "$GAME_DIR/PalWorldSettings.ini"

# Default Port for Palworld Dedicated Server
firewall_allow --port "8211" --udp

# Print some instructions and useful tips 
print_header 'Palworld Server Installation Complete'
echo 'Game server will auto-update on restarts and will auto-start on server boot.'
echo ''
echo "To restart:     sudo systemctl restart palworld"
echo "To start:       sudo systemctl start palworld"
echo "To stop:        sudo systemctl stop palworld"
echo "Game files:     $GAME_DIR/AppFiles/"
echo "Game settings:  $GAME_DIR/PalWorldSettings.ini"
