#!/bin/bash
#
# Install Zabbix Proxy [Linux]
#
# Please ensure to run this script as root (or at least with sudo)
#
# Generated with info from
# https://www.zabbix.com/download?zabbix=7.0&os_distribution=debian&os_version=12&components=agent_2&db=&ws=
#
#
# Syntax:
#   --noninteractive  - Run in non-interactive mode, (will not ask for prompts)
#   --version=<string> - Version of Zabbix to install DEFAULT=7.0
#   --server=<string> - Hostname or IP of Zabbix server (optional unless non-interactive)
#   --hostname=<string> - Hostname of local device for matching with a Zabbix host entry (optional unless non-interactive)
#
# TRMM Arguments:
#   --noninteractive
#   --version=7.0
#   --server={{client.zabbix_hostname}}
#   --hostname={{agent.fqdn}}
#
# Supports:
#   Debian 12
#   Ubuntu 24.04
#   Rocky 8, 9
#   CentOS 8, 9
#   RHEL 8, 9
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @CATEGORY Monitoring
# @TRMM-TIMEOUT 120
#
# Changelog:
#   20250130 - Change category to Monitoring
#   20250101 - Initial release

##
# Simple check to enforce the script to be run as root
if [ $(id -u) -ne 0 ]; then
	echo "This script must be run as root or with sudo!" >&2
	exit 1
fi
##
# Get the operating system
#
# almalinux, alpine, amzn, antergos, arch, archarm, arcolinux,
# centos, clear-linux-os, clearos,
# debian,
# elementary, endeavouros,
# fedora, freebsd,
# gentoo,
# kali,
# linuxmint,
# mageia, manjaro,
# nixos,
# opensuse, ol,
# pop,
# raspbian, rhel, rocky,
# scientific, slackware, sles,
# ubuntu,
# virtuozzo
#
function os() {
	if [ "$(uname -s)" == 'FreeBSD' ]; then
		echo 'freebsd'

	elif [ -f '/etc/os-release' ]; then
		local DISTRO="$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"

		if [[ "$DISTRO" =~ '"' ]]; then
			# Strip quotes around the OS name
			DISTRO="$(echo "$DISTRO" | sed 's:"::g')"
		fi

		# Cleanup a few known distro names
		if [ "$DISTRO" == "manjaro-arm" ]; then
			# Manjaro on ARM
			DISTRO="manjaro"
		elif [ "$DISTRO" == "opensuse-leap" ]; then
			# OpenSuSE Leap 15.x
			DISTRO="opensuse"
		elif [ "$DISTRO" == "sles_sap" ]; then
			# SuSE Enterprise SAP 12.x
			DISTRO="sles"
		fi

		echo "$DISTRO"

	else
		echo 'unknown'
	fi
}
##
# Get the operating system version
#
# Just the major version number is returned
#
function os_version() {
	if [ "$(uname -s)" == 'FreeBSD' ]; then
		local _V="$(uname -K)"
		if [ ${#_V} -eq 6 ]; then
			echo "${_V:0:1}"
		elif [ ${#_V} -eq 7 ]; then
			echo "${_V:0:2}"
		fi

	elif [ -f '/etc/os-release' ]; then
		local VERS="$(egrep '^VERSION_ID=' /etc/os-release | sed 's:VERSION_ID=::')"

		if [[ "$VERS" =~ '"' ]]; then
			# Strip quotes around the OS name
			VERS="$(echo "$VERS" | sed 's:"::g')"
		fi

		if [[ "$VERS" =~ \. ]]; then
			# Remove the decimal point and everything after
			# Trims "24.04" down to "24"
			VERS="${VERS/\.*/}"
		fi

		if [[ "$VERS" =~ "v" ]]; then
			# Remove the "v" from the version
			# Trims "v24" down to "24"
			VERS="${VERS/v/}"
		fi

		echo "$VERS"

	else
		echo 0
	fi
}
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
# Disable a package from a given yum repo
function yum_repo_excludepkg() {
	local REPO_FILE="$1"
	local PACKAGE="$2"
	if [ ! -e "$REPO_FILE" ]; then
		# If the repo file does not exist at all, nothing to do.
		return 1
	fi
	local STARTED=0
	local FOUND=0
	local TMP_FILE="$(mktemp)"
	local SECTION=""

	if [ -z "$TMP_FILE" ]; then
		# Ensure a temp file exists for temporary writing, (even if mktemp fails)
		TMP_FILE="/tmp/tmp.$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)"
		touch $TMP_FILE
	fi

	while read LINE; do
		if [[ "$LINE" =~ ^\[.*\] ]]; then
			# "[...] indicates the start of a new section
			if [ $STARTED -eq 1 -a $FOUND -eq 0 ]; then
				# If a new section has started with the directive being written, ensure it's written
				# prior to the next section starting.
				# Exception is the first section in the file.
				echo "Excluding $PACKAGE from $SECTION in $REPO_FILE"
				echo "excludepkgs=$PACKAGE" >> $TMP_FILE
				echo "" >> $TMP_FILE
			fi
			SECTION="$LINE"
			STARTED=1
			FOUND=0
		fi

		if [[ "$LINE" =~ ^excludepkgs= ]]; then
			# Line contains "excludepkgs", just append the requested package if necessary!
			FOUND=1
			if [ -z "$(echo $LINE | grep "$PACKAGE")" ]; then
				echo "Excluding $PACKAGE from $SECTION in $REPO_FILE"
				if [ "$LINE" == "excludepkgs=" ]; then
					LINE="$LINE$PACKAGE"
				else
					LINE="$LINE,$PACKAGE"
				fi
			fi
		fi

		if [ "$LINE" == "" -a $STARTED -eq 1 ]; then
			# End of a section
			if [ $FOUND -eq 0 ]; then
				echo "Excluding $PACKAGE from $SECTION in $REPO_FILE"
				echo "excludepkgs=$PACKAGE" >> $TMP_FILE
				FOUND=1
			fi
		fi
		echo "$LINE" >> $TMP_FILE
	done <$REPO_FILE

	if [ $FOUND -eq 0 ]; then
		# Last section in the file, if it was not written yet, ensure it's set.
		echo "Excluding $PACKAGE from $SECTION in $REPO_FILE"
		echo "excludepkgs=$PACKAGE" >> $TMP_FILE
	fi

	# Now that all operations are complete, replace the original file with the parsed one.
	mv $TMP_FILE $REPO_FILE
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
#
# CHANGELOG:
#   2025.04.10 - Set Debian frontend to noninteractive
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
		DEBIAN_FRONTEND="noninteractive" apt-get -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" install -y $*
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
# Setup the Zabbix repo for this OS, shared between agent, agent2, server, and proxy.
function zabbix_repo_setup() {
	local ZABBIX_VERSION="$1"
	local OS_NAME="$(os)"
	local OS_VERSION="$(os_version)"
	local BASE="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}"

	if [ -z "$(which wget)" ]; then
		package_install wget
	fi

	case "${ZABBIX_VERSION}_${OS_NAME}" in
		"7.2_almalinux" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/alma/${OS_VERSION}/noarch/zabbix-release-latest-7.2.el${OS_VERSION}.noarch.rpm";;
		"7.2_debian" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.2+debian${OS_VERSION}_all.deb";;
		"7.2_raspbian" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/raspbian/pool/main/z/zabbix-release/zabbix-release_latest_7.2+debian${OS_VERSION}_all.deb";;
		"7.2_rhel" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/rhel/${OS_VERSION}/noarch/zabbix-release-latest-7.2.el${OS_VERSION}.noarch.rpm";;
		"7.2_rocky" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/rocky/${OS_VERSION}/noarch/zabbix-release-latest-7.2.el${OS_VERSION}.noarch.rpm";;
		"7.2_ubuntu" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu${OS_VERSION}.04_all.deb";;

		"7.0_almalinux" ) local SRC="https://repo.zabbix.com/zabbix/7.0/alma/${OS_VERSION}/x86_64/zabbix-release-latest-7.0.el${OS_VERSION}.noarch.rpm";;
		"7.0_debian" ) local SRC="https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian${OS_VERSION}_all.deb";;
		"7.0_raspbian" ) local SRC="https://repo.zabbix.com/zabbix/7.0/raspbian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian${OS_VERSION}_all.deb";;
		"7.0_rhel" ) local SRC="https://repo.zabbix.com/zabbix/7.0/rhel/${OS_VERSION}/x86_64/zabbix-release-latest-7.0.el${OS_VERSION}.noarch.rpm";;
		"7.0_rocky" ) local SRC="https://repo.zabbix.com/zabbix/7.0/rocky/${OS_VERSION}/x86_64/zabbix-release-latest-7.0.el${OS_VERSION}.noarch.rpm";;
		"7.0_ubuntu" ) local SRC="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu${OS_VERSION}.04_all.deb";;

		"6.0_almalinux" ) local SRC="https://repo.zabbix.com/zabbix/6.0/rhel/${OS_VERSION}/x86_64/zabbix-release-latest-6.0.el${OS_VERSION}.noarch.rpm";;
		"6.0_debian" ) local SRC="https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_6.0+debian${OS_VERSION}_all.deb";;
		"6.0_raspbian" ) local SRC="https://repo.zabbix.com/zabbix/6.0/raspbian/pool/main/z/zabbix-release/zabbix-release_latest_6.0+debian${OS_VERSION}_all.deb";;
		"6.0_rhel" ) local SRC="https://repo.zabbix.com/zabbix/6.0/rhel/${OS_VERSION}/x86_64/zabbix-release-latest-6.0.el${OS_VERSION}.noarch.rpm";;
		"6.0_rocky" ) local SRC="https://repo.zabbix.com/zabbix/6.0/rocky/${OS_VERSION}/x86_64/zabbix-release-latest-6.0.el${OS_VERSION}.noarch.rpm";;
		"6.0_ubuntu" ) local SRC="https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_6.0+ubuntu${OS_VERSION}.04_all.deb";;
	esac

	local FILE="$(basename "$SRC")"

	# We will use this directory as a working directory for source files that need downloaded.
	[ -d /opt/script-collection ] || mkdir -p /opt/script-collection

	if [ ! -e /opt/script-collection/$FILE ]; then
		wget $SRC -O /opt/script-collection/$FILE
		if [ $? -ne 0 ]; then
			echo "Failed to download $SRC" >&2
			exit 1
		fi

		if [ $(os_like_debian) -eq 1 ]; then
			dpkg -i /opt/script-collection/$FILE
			apt update
		elif [ $(os_like_rhel) -eq 1 ]; then
			yum_repo_excludepkg /etc/yum.repos.d/epel.repo "zabbix*"
			rpm -Uvh /opt/script-collection/$FILE
			dnf clean all
		else
			echo "Unable to install $_FILE, unsupported OS [ $OS ] version [ $OSVERSIONMAJ ]" >&2
		fi
	fi
}
##
# Use sed to set a line in a config file
#
# If the target line does not exist, it will simply get appended to the end
#
# Arguments:
#   $1 Line match
#   $2 Line replace
#   $3 filename
#
# Example:
#   setconfigfile_orappend "^Password=.*" "Password=1234" "/etc/myapp/myapp.conf"
#
#
# CHANGELOG:
#   2025.04.10 - Escape '?' characters in the sed search
function setconfigfile_orappend() {
  # Swap '/' with '\/' since sed here uses '/' as the delimiter
  # Additionally, '?' characters in the SED search need escaped
  SED_SEARCH="$(echo "$1" | sed 's:/:\\/:g' | sed 's:?:\\\?:g')"
  SED_REPLACE="$(echo "$2" | sed 's:/:\\/:g')"
  GREP_SEARCH="$1"
  GREP_REPLACE="$2"
  FILENAME="$3"

  if grep -Eq "$GREP_SEARCH" "$FILENAME"; then
    if [ "$OSFAMILY" == "bsd" ]; then
      sed -i '' "s/$SED_SEARCH/$SED_REPLACE/" "$FILENAME"
    else
      sed -i "s/$SED_SEARCH/$SED_REPLACE/" "$FILENAME"
    fi
  else
    echo "$GREP_REPLACE" >> "$FILENAME"
  fi
}
##
# Prompt user for a text response
#
# Arguments:
#   --default="..."   Default text to use if no response is given
#
# Returns:
#   text as entered by user
#
function prompt_text() {
	local DEFAULT=""
	local PROMPT="Enter some text"
	local RESPONSE=""

	while [ $# -ge 1 ]; do
		case $1 in
			--default=*) DEFAULT="${1#*=}";;
			*) PROMPT="$1";;
		esac
		shift
	done

	echo "$PROMPT" >&2
	echo -n '> : ' >&2
	read RESPONSE
	if [ "$RESPONSE" == "" ]; then
		echo "$DEFAULT"
	else
		echo "$RESPONSE"
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
# Generate a random password, (using characters that are easy to read and type)
function random_password() {
	< /dev/urandom tr -dc _cdefhjkmnprtvwxyACDEFGHJKLMNPQRTUVWXY2345689 | head -c${1:-24};echo;
}
# Variable setup
ZABBIX_AGENT_CONFIGURATION="/etc/zabbix/zabbix_proxy.conf"

function usage() {
  cat >&2 <<EOD
Usage: $0 [options]

Options:
    --noninteractive  - Run in non-interactive mode, (will not ask for prompts)
    --version=<string> - Version of Zabbix to install DEFAULT=7.0
    --server=<string> - Hostname or IP of Zabbix server (optional unless non-interactive)
    --hostname=<string> - Hostname of local device for matching with a Zabbix host entry (optional unless non-interactive)

Please ensure to run this script as root (or at least with sudo)

Generated with info from
https://www.zabbix.com/download?zabbix=7.0&os_distribution=debian&os_version=12&components=agent_2&db=&ws=
EOD
  exit 1
}

# Parse arguments
NONINTERACTIVE=0
VERSION="7.0"
ZABBIX_SERVER=""
ZABBIX_AGENT_HOSTNAME=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--noninteractive) NONINTERACTIVE=1; shift 1;;
		--version=*)
			VERSION="${1#*=}";
			if [ "${VERSION:0:1}" == "'" -a "${VERSION:0-1}" == "'" ]; then VERSION="${VERSION:1:-1}"; fi;
			if [ "${VERSION:0:1}" == '"' -a "${VERSION:0-1}" == '"' ]; then VERSION="${VERSION:1:-1}"; fi;
			shift 1;;
		--server=*)
			ZABBIX_SERVER="${1#*=}";
			if [ "${ZABBIX_SERVER:0:1}" == "'" -a "${ZABBIX_SERVER:0-1}" == "'" ]; then ZABBIX_SERVER="${ZABBIX_SERVER:1:-1}"; fi;
			if [ "${ZABBIX_SERVER:0:1}" == '"' -a "${ZABBIX_SERVER:0-1}" == '"' ]; then ZABBIX_SERVER="${ZABBIX_SERVER:1:-1}"; fi;
			shift 1;;
		--hostname=*)
			ZABBIX_AGENT_HOSTNAME="${1#*=}";
			if [ "${ZABBIX_AGENT_HOSTNAME:0:1}" == "'" -a "${ZABBIX_AGENT_HOSTNAME:0-1}" == "'" ]; then ZABBIX_AGENT_HOSTNAME="${ZABBIX_AGENT_HOSTNAME:1:-1}"; fi;
			if [ "${ZABBIX_AGENT_HOSTNAME:0:1}" == '"' -a "${ZABBIX_AGENT_HOSTNAME:0-1}" == '"' ]; then ZABBIX_AGENT_HOSTNAME="${ZABBIX_AGENT_HOSTNAME:1:-1}"; fi;
			shift 1;;
		-h|--help) usage;;
	esac
done


if [ -z "$VERSION" ]; then
	VERSION="7.0"
fi
if [ "$VERSION" == "latest" ]; then
	VERSION="7.2"
fi

# User prompts (if not in non-interactive mode)
if [ $NONINTERACTIVE -eq 0 ]; then
	if [ -z "$ZABBIX_SERVER" ]; then
		ZABBIX_SERVER="$(prompt_text "Hostname or IP of Zabbix server")"
	fi
	if [ -z "$ZABBIX_AGENT_HOSTNAME" ]; then
		ZABBIX_AGENT_HOSTNAME="$(prompt_text "Hostname of local device for matching with a Zabbix host entry" --default="$(hostname -f)")"
	fi
else
	if [ -z "$ZABBIX_SERVER" ]; then
		usage
	fi
	if [ -z "$ZABBIX_AGENT_HOSTNAME" ]; then
		usage
	fi
fi

# Setup Zabbix repo
zabbix_repo_setup "$VERSION"

# Install the proxy
package_install zabbix-proxy-mysql zabbix-sql-scripts
if [ $(os_like_rhel) -eq 1 ]; then
	package_install zabbix-selinux-policy
fi


# Setup config from user-definable parameters
setconfigfile_orappend "^Server=.*" "Server=${ZABBIX_SERVER}" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^Hostname=.*" "Hostname=${ZABBIX_AGENT_HOSTNAME}" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^EnableRemoteCommands=.*" "EnableRemoteCommands=1" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^AllowUnsupportedDBVersions=.*" "AllowUnsupportedDBVersions=1" "$ZABBIX_AGENT_CONFIGURATION"

# If no password has been set, presume that Zabbix isn't configured yet.
if grep -q '# DBPassword=' /etc/zabbix/zabbix_proxy.conf; then
	# Generate a random password for Zabbix
	DBPASS="$(random_password)"
	mysql -e "create database zabbix_proxy character set utf8mb4 collate utf8mb4_bin"
	mysql -e "create user zabbix@localhost identified by '$DBPASS'"
	mysql -e "grant all privileges on zabbix_proxy.* to zabbix@localhost"
	mysql -e "set global log_bin_trust_function_creators = 1"

	# Install the initial data
	cat /usr/share/zabbix-sql-scripts/mysql/proxy.sql | mysql --default-character-set=utf8mb4 zabbix_proxy

	# Disable log_bin_trust_function_creators option after importing database schema.
	mysql -e "set global log_bin_trust_function_creators = 0"

	# Set the password in Zabbix's config file
	sed -i "s/# DBPassword=/DBPassword=$DBPASS/g" /etc/zabbix/zabbix_proxy.conf
fi

# Restart and enable the service
systemctl restart zabbix-proxy
systemctl enable zabbix-proxy

print_header 'Zabbix proxy installed'
echo "Agent Version:   $VERSION"
echo "Zabbix Server:   $ZABBIX_SERVER"
echo "Device Hostname: $ZABBIX_AGENT_HOSTNAME"
echo ''
echo 'If you have not done so already, please create a new Proxy in Zabbix for this device.'
echo '(Administration -> Proxies -> Create Proxy)'
echo ''
echo 'Followed by setting its IP range and checks enabled'
echo '(Data collection -> Discovery)'
