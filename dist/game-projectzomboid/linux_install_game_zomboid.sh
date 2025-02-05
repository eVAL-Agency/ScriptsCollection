#!/bin/bash
#
# Install Project Zomboid
#
# Please ensure to run this script as root (or at least with sudo)
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
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
#
# Changelog:
#   20241230 - Initial release

############################################
## Parameter Configuration
############################################

GAME="Zomboid"
GAME_USER="steam"
GAME_DIR="/home/$GAME_USER/$GAME"
STEAM_DIR="/home/$GAME_USER/.local/share/Steam"

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
function os_like_debian() {
	if [ -f '/etc/os-release' ]; then
		ID="$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"
		LIKE="$(egrep '^ID_LIKE=' /etc/os-release | sed 's:ID_LIKE=::')"

		if [[ "$LIKE" =~ 'debian' ]]; then echo 1; return; fi
		if [[ "$LIKE" =~ 'ubuntu' ]]; then echo 1; return; fi
		if [ "$ID" == 'debian' ]; then echo 1; return; fi
		if [ "$ID" == 'ubuntu' ]; then echo 1; return; fi
	fi

	echo 0
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
function os_like_ubuntu() {
	if [ -f '/etc/os-release' ]; then
		ID="$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"
		LIKE="$(egrep '^ID_LIKE=' /etc/os-release | sed 's:ID_LIKE=::')"

		if [[ "$LIKE" =~ 'ubuntu' ]]; then echo 1; return; fi
		if [ "$ID" == 'ubuntu' ]; then echo 1; return; fi
	fi

	echo 0
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
function os_like_rhel() {
	if [ -f '/etc/os-release' ]; then
		ID="$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"
		LIKE="$(egrep '^ID_LIKE=' /etc/os-release | sed 's:ID_LIKE=::')"

		if [[ "$LIKE" =~ 'rhel' ]]; then echo 1; return; fi
		if [[ "$LIKE" =~ 'fedora' ]]; then echo 1; return; fi
		if [[ "$LIKE" =~ 'centos' ]]; then echo 1; return; fi
		if [ "$ID" == 'rhel' ]; then echo 1; return; fi
		if [ "$ID" == 'fedora' ]; then echo 1; return; fi
		if [ "$ID" == 'centos' ]; then echo 1; return; fi
	fi

	echo 0
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
function os_like_suse() {
	if [ -f '/etc/os-release' ]; then
		ID="$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"
		LIKE="$(egrep '^ID_LIKE=' /etc/os-release | sed 's:ID_LIKE=::')"

		if [[ "$LIKE" =~ 'suse' ]]; then echo 1; return; fi
		if [ "$ID" == 'suse' ]; then echo 1; return; fi
	fi

	echo 0
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
function os_like_arch() {
	if [ -f '/etc/os-release' ]; then
		ID="$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"
		LIKE="$(egrep '^ID_LIKE=' /etc/os-release | sed 's:ID_LIKE=::')"

		if [[ "$LIKE" =~ 'arch' ]]; then echo 1; return; fi
		if [ "$ID" == 'arch' ]; then echo 1; return; fi
	fi

	echo 0
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
function os_like_bsd() {
	if [ "$(uname -s)" == 'FreeBSD' ]; then
		echo 1
	else
		echo 0
	fi
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
function os_like_macos() {
	if [ "$(uname -s)" == 'Darwin' ]; then
		echo 1
	else
		echo 0
	fi
}

##
# Install SteamCMD
function install_steamcmd() {
	echo "Installing SteamCMD..."

	TYPE_DEBIAN="$(os_like_debian)"
	TYPE_UBUNTU="$(os_like_ubuntu)"

	# Preliminary requirements
	if [ "$TYPE_UBUNTU" == 1 ]; then
		add-apt-repository -y multiverse
		dpkg --add-architecture i386
		apt update

		# By using this script, you agree to the Steam license agreement at https://store.steampowered.com/subscriber_agreement/
		# and the Steam privacy policy at https://store.steampowered.com/privacy_agreement/
		# Since this is meant to support unattended installs, we will forward your acceptance of their license.
		echo steam steam/question select "I AGREE" | debconf-set-selections
		echo steam steam/license note '' | debconf-set-selections

		apt install -y steamcmd
	elif [ "$TYPE_DEBIAN" == 1 ]; then
		dpkg --add-architecture i386
		apt update
		apt install -y software-properties-common apt-transport-https dirmngr ca-certificates lib32gcc-s1

		# Enable "non-free" repos for Debian (for steamcmd)
		# https://stackoverflow.com/questions/76688863/apt-add-repository-doesnt-work-on-debian-12
		add-apt-repository -y -U http://deb.debian.org/debian -c non-free-firmware -c non-free
		if [ $? -ne 0 ]; then
			echo "Workaround failed to add non-free repos, trying new method instead"
			apt-add-repository -y non-free
		fi

		# Install steam repo
		curl -s http://repo.steampowered.com/steam/archive/stable/steam.gpg > /usr/share/keyrings/steam.gpg
		echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/steam.gpg] http://repo.steampowered.com/steam/ stable steam" > /etc/apt/sources.list.d/steam.list

		# By using this script, you agree to the Steam license agreement at https://store.steampowered.com/subscriber_agreement/
		# and the Steam privacy policy at https://store.steampowered.com/privacy_agreement/
		# Since this is meant to support unattended installs, we will forward your acceptance of their license.
		echo steam steam/question select "I AGREE" | debconf-set-selections
		echo steam steam/license note '' | debconf-set-selections

		# Install steam binary and steamcmd
		apt update
		apt install -y steamcmd
	else
		echo 'Unsupported or unknown OS' >&2
		exit 1
	fi
}
##
# Print a header message
#
function print_header() {
	local header="$1"
	echo "================================================================================"
	printf "%*s\n" $(((${#header}+80)/2)) "$header"
    echo ""
}
##
# Get which firewall is enabled,
# or "none" if none located
function get_enabled_firewall() {
	if [ "$(systemctl is-active firewalld)" == "active" ]; then
		echo "firewalld"
	elif [ "$(systemctl is-active ufw)" == "active" ]; then
		echo "ufw"
	elif [ "$(systemctl is-active iptables)" == "active" ]; then
		echo "iptables"
	else
		echo "none"
	fi
}

##
# Get which firewall is available on the local system,
# or "none" if none located
function get_available_firewall() {
	if systemctl list-unit-files firewalld.service &>/dev/null; then
		echo "firewalld"
	elif systemctl list-unit-files ufw.service &>/dev/null; then
		echo "ufw"
	elif systemctl list-unit-files iptables.service &>/dev/null; then
		echo "iptables"
	else
		echo "none"
	fi
}
##
# Add an "allow" rule to the firewall in the INPUT chain
#
# Arguments:
#   --port <port>       Port(s) to allow
#   --source <source>   Source IP to allow (default: any)
#   --zone <zone>       Zone to allow (default: public)
#   --tcp|--udp         Protocol to allow (default: tcp)
#   --comment <comment> (only UFW) Comment for the rule
#
# Specify multiple ports with `--port '#,#,#'` or a range `--port '#:#'`
function firewall_allow() {
	# Defaults and argument processing
	local PORT=""
	local PROTO="tcp"
	local SOURCE="any"
	local FIREWALL=$(get_available_firewall)
	local ZONE="public"
	local COMMENT=""
	while [ $# -ge 1 ]; do
		case $1 in
			--port)
				shift
				PORT=$1
				;;
			--tcp|--udp)
				PROTO=${1:2}
				;;
			--source|--from)
				shift
				SOURCE=$1
				;;
			--zone)
				shift
				ZONE=$1
				;;
			--comment)
				shift
				COMMENT=$1
				;;
			*)
				PORT=$1
				;;
		esac
		shift
	done

	if [ "$PORT" == "" -a "$ZONE" != "trusted" ]; then
		echo "firewall_allow: No port specified!" >&2
		exit 1
	fi

	if [ "$PORT" != "" -a "$ZONE" == "trusted" ]; then
		echo "firewall_allow: Trusted zones do not use ports!" >&2
		exit 1
	fi

	if [ "$ZONE" == "trusted" -a "$SOURCE" == "any" ]; then
		echo "firewall_allow: Trusted zones require a source!" >&2
		exit 1
	fi

	if [ "$FIREWALL" == "ufw" ]; then
		if [ "$SOURCE" == "any" ]; then
			echo "firewall_allow/UFW: Allowing $PORT/$PROTO from any..."
			ufw allow proto $PROTO to any port $PORT comment "$COMMENT"
		elif [ "$ZONE" == "trusted" ]; then
			echo "firewall_allow/UFW: Allowing all connections from $SOURCE..."
			ufw allow from $SOURCE comment "$COMMENT"
		else
			echo "firewall_allow/UFW: Allowing $PORT/$PROTO from $SOURCE..."
			ufw allow from $SOURCE proto $PROTO to any port $PORT comment "$COMMENT"
		fi
	elif [ "$FIREWALL" == "firewalld" ]; then
		if [ "$SOURCE" != "any" ]; then
			# Firewalld uses Zones to specify sources
			echo "firewall_allow/firewalld: Adding $SOURCE to $ZONE zone..."
			firewall-cmd --zone=$ZONE --add-source=$SOURCE --permanent
		fi

		if [ "$PORT" != "" ]; then
			echo "firewall_allow/firewalld: Allowing $PORT/$PROTO in $ZONE zone..."
			if [[ "$PORT" =~ ":" ]]; then
				# firewalld expects port ranges to be in the format of "#-#" vs "#:#"
				local DPORTS="${PORT/:/-}"
				firewall-cmd --zone=$ZONE --add-port=$DPORTS/$PROTO --permanent
			elif [[ "$PORT" =~ "," ]]; then
				# Firewalld cannot handle multiple ports all that well, so split them by the comma
				# and run the add command separately for each port
				local DPORTS="$(echo $PORT | sed 's:,: :g')"
				for P in $DPORTS; do
					firewall-cmd --zone=$ZONE --add-port=$P/$PROTO --permanent
				done
			else
				firewall-cmd --zone=$ZONE --add-port=$PORT/$PROTO --permanent
			fi
		fi

		firewall-cmd --reload
	elif [ "$FIREWALL" == "iptables" ]; then
		echo "firewall_allow/iptables: WARNING - iptables is untested"
		# iptables doesn't natively support multiple ports, so we have to get creative
		if [[ "$PORT" =~ ":" ]]; then
			local DPORTS="-m multiport --dports $PORT"
		elif [[ "$PORT" =~ "," ]]; then
			local DPORTS="-m multiport --dports $PORT"
		else
			local DPORTS="--dport $PORT"
		fi

		if [ "$SOURCE" == "any" ]; then
			echo "firewall_allow/iptables: Allowing $PORT/$PROTO from any..."
			iptables -A INPUT -p $PROTO $DPORTS -j ACCEPT
		else
			echo "firewall_allow/iptables: Allowing $PORT/$PROTO from $SOURCE..."
			iptables -A INPUT -p $PROTO $DPORTS -s $SOURCE -j ACCEPT
		fi
		iptables-save > /etc/iptables/rules.v4
	elif [ "$FIREWALL" == "none" ]; then
		echo "firewall_allow: No firewall detected" >&2
		exit 1
	else
		echo "firewall_allow: Unsupported or unknown firewall" >&2
		echo 'Please report this at https://github.com/cdp1337/ScriptsCollection/issues' >&2
		exit 1
	fi
}

##
# Install a package with the system's package manager.
#
# Uses Redhat's yum, Debian's apt-get, and SuSE's zypper.
#
# Usage:
#
# ```syntax-shell
# package_install apache2 php7.0 mariadb-server
# ```
#
# @param $1..$N string
#        Package, (or packages), to install.  Accepts multiple packages at once.
#
function package_install (){
	echo "package_install: Installing $*..."

	TYPE_BSD="$(os_like_bsd)"
	TYPE_DEBIAN="$(os_like_debian)"
	TYPE_RHEL="$(os_like_rhel)"
	TYPE_ARCH="$(os_like_arch)"
	TYPE_SUSE="$(os_like_suse)"

	if [ "$TYPE_BSD" == 1 ]; then
		pkg install -y $*
	elif [ "$TYPE_DEBIAN" == 1 ]; then
		apt-get -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" install -y $*
	elif [ "$TYPE_RHEL" == 1 ]; then
		yum install -y $*
	elif [ "$TYPE_ARCH" == 1 ]; then
		pacman -Syu --noconfirm $*
	elif [ "$TYPE_SUSE" == 1 ]; then
		zypper install -y $*
	else
		echo 'package_install: Unsupported or unknown OS' >&2
		echo 'Please report this at https://github.com/cdp1337/ScriptsCollection/issues' >&2
		exit 1
	fi
}

##
# Install UFW
#
function install_ufw() {
	if [ "$(os_like_rhel)" == 1 ]; then
		# RHEL/CentOS requires EPEL to be installed first
		package_install epel-release
	fi

	package_install ufw

	# Auto-enable a newly installed firewall
	ufw --force enable
	systemctl enable ufw
	systemctl start ufw

	# Auto-add the current user's remote IP to the whitelist (anti-lockout rule)
	local TTY_IP="$(who am i | awk '{print $5}' | sed 's/[()]//g')"
	if [ -n "$TTY_IP" ]; then
		ufw allow from $TTY_IP comment 'Anti-lockout rule based on first install of UFW'
	fi
}

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
