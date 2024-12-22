#!/bin/bash
#
# Install script for ARK Survival Ascended on Debian 12
#
# Uses Glorious Eggroll's build of Proton
# Please ensure to run this script as root (or at least with sudo)
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell - cdp1337@veraciousnetwork.com
# @SOURCE  https://github.com/cdp1337/ARKSurvivalAscended-Linux
#
# F*** Nitrado


############################################
## Parameter Configuration
############################################

# https://github.com/GloriousEggroll/proton-ge-custom
PROTON_VERSION="9-20"
GAME="ArkSurvivalAscended"
GAME_USER="steam"
GAME_DIR="/home/$GAME_USER/$GAME"
# Force installation directory for game
# steam produces varying results, sometimes in ~/.local/share/Steam, other times in ~/Steam
STEAM_DIR="/home/$GAME_USER/.local/share/Steam"
# Specific "filesystem" directory for installed version of Proton
GAME_COMPAT_DIR="/opt/script-collection/GE-Proton${PROTON_VERSION}/files/share/default_pfx"
# Binary path for Proton
PROTON_BIN="/opt/script-collection/GE-Proton${PROTON_VERSION}/proton"
# List of game maps currently available
GAME_MAPS="ark-island ark-aberration ark-club ark-scorched ark-thecenter ark-extinction"
# Range of game ports to enable in the firewall
PORT_GAME_START=7701
PORT_GAME_END=7706
PORT_RCON_START=27001
PORT_RCON_END=27006


# scriptlet:install/proton/install.sh
# scriptlet:checks/firewall/get_firewall.sh
# scriptlet:install/steam/install-steamcmd.sh
# scriptlet:install/firewalld/install.sh



############################################
## Pre-exec Checks
############################################

# Only allow running as root
if [ "$LOGNAME" != "root" ]; then
	echo "Please run this script as root! (If you ran with 'su', use 'su -' instead)" >&2
	exit 1
fi

# This script can run on an existing server, but should not run while the game is actively running.
if [ $(ps aux | grep ArkAscendedServer.exe | wc -l) -gt 1 ]; then
	echo "It appears that the ARK server is already running, please stop it before running this script."
	exit 1
fi

# Determine if this is a new installation or an upgrade (/repair)
if [ -e /etc/systemd/system/ark-island.service ]; then
	INSTALLTYPE="upgrade"
else
	INSTALLTYPE="new"
fi

# Determine if there is a firewall already installed, (to prevent issues)
# Addresses Issue #19
FIREWALL=$(get_enabled_firewall)


############################################
## User Prompts (pre setup)
############################################

# Ask the user some information before installing.
echo "================================================================================"
echo "         	  ARK Survival Ascended *unofficial* Installer"
echo ""
if [ "$INSTALLTYPE" == "new" ]; then
	echo "? What is the community name of the server? (e.g. My Awesome ARK Server)"
	echo -n "> "
	read COMMUNITYNAME
	if [ "$COMMUNITYNAME" == "" ]; then
		COMMUNITYNAME="My Awesome ARK Server"
	fi
fi


############################################
## Dependency Installation and Setup
############################################

# Create a "steam" user account
# This will create the account with no password, so if you need to log in with this user,
# run `sudo passwd steam` to set a password.
if [ -z "$(getent passwd $GAME_USER)" ]; then
	useradd -m -U $GAME_USER
fi

# Preliminary requirements
apt install -y curl wget sudo

if [ "$FIREWALL" == "none" ]; then
	# No firewall installed, go ahead and install firewalld
	install_firewalld
fi

# Install steam binary and steamcmd
install_steamcmd

# Grab Proton from Glorious Eggroll
install_proton "$PROTON_VERSION"


############################################
## Upgrade Checks
############################################

for MAP in $GAME_MAPS; do
	# Ensure the override directory exists for the admin modifications to the CLI arguments.
	[ -e /etc/systemd/system/${MAP}.service.d ] || mkdir -p /etc/systemd/system/${MAP}.service.d

	# Release 2023.10.31 - Issue #8
	if [ -e /etc/systemd/system/${MAP}.service ]; then
		# Check if the service is already installed and move any modifications to the override.
		# This is important for existing installs so the admin modifications to CLI arguments do not get overwritten.

		if [ ! -e /etc/systemd/system/${MAP}.service.d/override.conf ]; then
			# Override does not exist yet, merge in any changes in the default service file.
			SERVICE_EXEC_LINE="$(grep -E '^ExecStart=' /etc/systemd/system/${MAP}.service)"

			cat > /etc/systemd/system/${MAP}.service.d/override.conf <<EOF
[Service]
$SERVICE_EXEC_LINE
EOF
		fi
	fi
done
## End Release 2023.10.31 - Issue #8


############################################
## Game Installation
############################################

# Install ARK Survival Ascended Dedicated
sudo -u $GAME_USER /usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 2430930 validate +quit
# STAGING / TESTING - skip ark because it's huge; AppID 90 is Team Fortress 1 (a tiny server useful for testing)
#sudo -u steam /usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 90 validate +quit
if [ $? -ne 0 ]; then
	echo "Could not install ARK Survival Ascended Dedicated Server, exiting" >&2
	exit 1
fi


# Install the systemd service files for ARK Survival Ascended Dedicated Server
for MAP in $GAME_MAPS; do
	# Different maps will have different settings, (to allow them to coexist on the same server)
	if [ "$MAP" == "ark-island" ]; then
		DESC="Island"
		NAME="TheIsland_WP"
		MODS=""
		GAMEPORT=7701
		RCONPORT=27001
	elif [ "$MAP" == "ark-aberration" ]; then
		DESC="Aberration"
		NAME="Aberration_WP"
		MODS=""
		GAMEPORT=7702
		RCONPORT=27002
	elif [ "$MAP" == "ark-club" ]; then
		DESC="Club"
		NAME="BobsMissions_WP"
		MODS="1005639"
		GAMEPORT=7703
		RCONPORT=27003
	elif [ "$MAP" == "ark-scorched" ]; then
		DESC="Scorched"
		NAME="ScorchedEarth_WP"
		MODS=""
		GAMEPORT=7704
		RCONPORT=27004
	elif [ "$MAP" == "ark-thecenter" ]; then
		DESC="TheCenter"
		NAME="TheCenter_WP"
		MODS=""
		GAMEPORT=7705
		RCONPORT=27005
	elif [ "$MAP" == "ark-extinction" ]; then
		DESC="Extinction"
		NAME="Extinction_WP"
		MODS=""
		GAMEPORT=7706
		RCONPORT=27006
	fi


	# Install system service file to be loaded by systemd
	cat > /etc/systemd/system/${MAP}.service <<EOF
[Unit]
# DYNAMICALLY GENERATED FILE! Edit at your own risk
Description=ARK Survival Ascended Dedicated Server (${DESC})
After=network.target
After=ark-updater.service

[Service]
Type=simple
LimitNOFILE=10000
User=$GAME_USER
Group=$GAME_USER
WorkingDirectory=$GAME_DIR/AppFiles/ShooterGame/Binaries/Win64
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)
Environment="STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_DIR"
Environment="STEAM_COMPAT_DATA_PATH=$GAME_DIR/prefixes/$MAP"
# Check $GAME_DIR/services to adjust the CLI arguments
Restart=on-failure
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF

	if [ ! -e /etc/systemd/system/${MAP}.service.d/override.conf ]; then
		# Override does not exist yet, create boilerplate file.
		# This is the main file that the admin will use to modify CLI arguments,
		# so we do not want to overwrite their work if they have already modified it.
		cat > /etc/systemd/system/${MAP}.service.d/override.conf <<EOF
[Service]
# Edit this line to adjust start parameters of the server
# After modifying, please remember to run `sudo systemctl daemon-reload` to apply changes to the system.
ExecStart=$PROTON_BIN run ArkAscendedServer.exe ${NAME}?listen?SessionName="${COMMUNITYNAME} (${DESC})"?RCONPort=${RCONPORT} -port=${GAMEPORT} -servergamelog -mods=$MODS
EOF
    fi

    # Set the owner of the override to steam so that user account can modify it.
    chown $GAME_USER:$GAME_USER /etc/systemd/system/${MAP}.service.d/override.conf

    if [ ! -e $GAME_DIR/prefixes/$MAP ]; then
    	# Install a new prefix for this specific map
    	# Proton 9 seems to have issues with launching multiple binaries in the same prefix.
    	[ -d $GAME_DIR/prefixes ] || sudo -u $GAME_USER mkdir -p $GAME_DIR/prefixes
		sudo -u $GAME_USER cp $GAME_COMPAT_DIR $GAME_DIR/prefixes/$MAP -r
	fi
done

# Create update helper and service
# Install system service file to be loaded by systemd
cat > /etc/systemd/system/ark-updater.service <<EOF
[Unit]
# DYNAMICALLY GENERATED FILE! Edit at your own risk
Description=ARK Survival Ascended Dedicated Server Updater
After=network.target

[Service]
Type=oneshot
User=$GAME_USER
Group=$GAME_USER
WorkingDirectory=$GAME_DIR/AppFiles/ShooterGame/Binaries/Win64
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)
ExecStart=$GAME_DIR/update.sh

[Install]
WantedBy=multi-user.target
EOF

cat > $GAME_DIR/update.sh <<EOF
#!/bin/bash
#
# Update ARK Survival Ascended Dedicated Server
#
# DYNAMICALLY GENERATED FILE! Edit at your own risk

# List of all maps available on this platform
GAME_MAPS="$GAME_MAPS"

# This script is expected to be run as the steam user, (as that is the owner of the game files).
# If another user calls this script, sudo will be used to switch to the steam user.
if [ "\$(whoami)" == "$GAME_USER" ]; then
	SUDO_NEEDED=0
else
	SUDO_NEEDED=1
fi

function update_game {
	echo "Running game update"
	if [ "\$SUDO_NEEDED" -eq 1 ]; then
		sudo -u $GAME_USER /usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 2430930 validate +quit
	else
		/usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 2430930 validate +quit
	fi

	if [ \$? -ne 0 ]; then
		echo "Game update failed!" >&2
		exit 1
	fi
}

# Check if any maps are running; do not update an actively running server.
RUNNING=0
for MAP in \$GAME_MAPS; do
	if [ "\$(systemctl is-active $MAP)" == "active" ]; then
		RUNNING=1
	fi
done
if [ \$RUNNING -eq 0 ]; then
	update_game
else
	echo "Game server is already running, not updating"
fi
EOF
chown $GAME_USER:$GAME_USER $GAME_DIR/update.sh
chmod +x $GAME_DIR/update.sh
systemctl daemon-reload
systemctl enable ark-updater


# Create start/stop helpers for all maps
cat > $GAME_DIR/start_all.sh <<EOF
#!/bin/bash
#
# Start all ARK server maps that are enabled
# DYNAMICALLY GENERATED FILE! Edit at your own risk

# List of all maps available on this platform
GAME_MAPS="$GAME_MAPS"

function start_game {
	echo "Starting game instance \$1..."
	sudo systemctl start \$1
	echo "Waiting 60 seconds for threads to start"
	for i in {0..9}; do
		sleep 6
		echo -n '.'
	done
	# Check status real quick
	sudo systemctl status \$1 | grep Active
}

function update_game {
	echo "Running game update"
	sudo -u $GAME_USER /usr/games/steamcmd +force_install_dir $GAME_DIR/AppFiles +login anonymous +app_update 2430930 validate +quit
	if [ \$? -ne 0 ]; then
		echo "Game update failed, not starting"
		exit 1
	fi
}

RUNNING=0
for MAP in \$GAME_MAPS; do
	if [ "\$(systemctl is-active $MAP)" == "active" ]; then
		RUNNING=1
	fi
done
if [ \$RUNNING -eq 0 ]; then
	update_game
else
	echo "Game server is already running, not updating"
fi

for MAP in \$GAME_MAPS; do
	if [ "\$(systemctl is-enabled \$MAP)" == "enabled" -a "\$(systemctl is-active \$MAP)" == "inactive" ]; then
		start_game \$MAP
	fi
done
EOF
chown $GAME_USER:$GAME_USER $GAME_DIR/start_all.sh
chmod +x $GAME_DIR/start_all.sh


cat > $GAME_DIR/stop_all.sh <<EOF
#!/bin/bash
#
# Stop all ARK server maps that are enabled
# DYNAMICALLY GENERATED FILE! Edit at your own risk

# List of all maps available on this platform
GAME_MAPS="$GAME_MAPS"

function stop_game {
	echo "Stopping game instance \$1..."
	sudo systemctl stop \$1
	echo "Waiting 10 seconds for threads to settle"
	for i in {0..9}; do
		echo -n '.'
		sleep 1
	done
	# Check status real quick
	sudo systemctl status \$1 | grep Active
}

for MAP in \$GAME_MAPS; do
	if [ "\$(systemctl is-enabled \$MAP)" == "enabled" -a "\$(systemctl is-active \$MAP)" == "active" ]; then
		stop_game \$MAP
	fi
done
EOF
chown $GAME_USER:$GAME_USER $GAME_DIR/stop_all.sh
chmod +x $GAME_DIR/stop_all.sh


# Reload systemd to pick up the new service files
systemctl daemon-reload


############################################
## Security Configuration
############################################

if [ "$FIREWALL" == "ufw" ]; then
	# Enable rules for UFW
	ufw allow ${PORT_GAME_START}:${PORT_GAME_END}/udp
	ufw allow ${PORT_RCON_START}:${PORT_RCON_END}/tcp
elif [ "$FIREWALL" == "firewalld" ]; then
	# Install/enable rules for Firewalld
	[ -d "/etc/firewalld/services" ] || mkdir -p /etc/firewalld/services
    cat > /etc/firewalld/services/ark-survival.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>ARK Survival Ascended</short>
  <description>ARK Survival Ascended game server</description>
  <port port="${PORT_GAME_START}-${PORT_GAME_END}" protocol="udp"/>
  <port port="${PORT_RCON_START}-${PORT_RCON_END}" protocol="tcp"/>
</service>
EOF
	systemctl restart firewalld
    firewall-cmd --permanent --zone=public --add-service=ark-survival
fi


############################################
## Post-Install Configuration
############################################

# Create some helpful links for the user.
[ -e "$GAME_DIR/services" ] || sudo -u steam mkdir -p "$GAME_DIR/services"
for MAP in $GAME_MAPS; do
	[ -h "$GAME_DIR/services/${MAP}.conf" ] || sudo -u steam ln -s /etc/systemd/system/${MAP}.service.d/override.conf "$GAME_DIR/services/${MAP}.conf"
done
[ -h "$GAME_DIR/GameUserSettings.ini" ] || sudo -u steam ln -s $GAME_DIR/AppFiles/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini "$GAME_DIR/GameUserSettings.ini"
[ -h "$GAME_DIR/Game.ini" ] || sudo -u steam ln -s $GAME_DIR/AppFiles/ShooterGame/Saved/Config/WindowsServer/Game.ini "$GAME_DIR/Game.ini"
[ -h "$GAME_DIR/ShooterGame.log" ] || sudo -u steam ln -s $GAME_DIR/AppFiles/ShooterGame/Saved/Logs/ShooterGame.log "$GAME_DIR/ShooterGame.log"


echo "================================================================================"
echo "If everything went well, ARK Survival Ascended should be installed!"
echo ""
for MAP in $GAME_MAPS; do
	if [ "$(systemctl is-enabled $MAP)" == "enabled" ]; then
		echo "Game map ${MAP} is already enabled"
	else
		echo "? Enable game map ${MAP}? (y/N)"
		echo -n "> "
		read OPT
		if [ "$OPT" == "y" -o "$OPT" == "Y" ]; then
			systemctl enable $MAP
		else
			echo "Not enabling ${MAP}, you can always enable it in the future with 'sudo systemctl enable $MAP'"
		fi
	fi
	echo ""
done
echo ""
echo "To restart a map:      sudo systemctl restart NAME-OF-MAP"
echo "To start a map:        sudo systemctl start NAME-OF-MAP"
echo "To stop a map:         sudo systemctl stop NAME-OF-MAP"
echo "Game files:            $GAME_DIR/AppFiles/"
echo "Runtime configuration: $GAME_DIR/services/"
echo "Game log:              $GAME_DIR/ShooterGame.log"
echo "Game user settings:    $GAME_DIR/GameUserSettings.ini"
echo "To start all maps:     $GAME_DIR/start_all.sh"
echo "To stop all maps:      $GAME_DIR/stop_all.sh"
