#!/bin/bash
#
# Install Graylog Sidecar [Linux]
#
#
# Syntax:
#   --server=<string> - ... - Fully resolved URL of Graylog server, including http(s)://, port, and /api (REQUIRED)
#   GRAYLOG_TOKEN (environmental variable) - API token for the Graylog server (REQUIRED)
#
# TRMM Arguments:
#   --server={{client.graylog_server}}
#
# TRMM Environment:
#   GRAYLOG_TOKEN={{client.graylog_token}}
#
# Supports:
#   Debian 12
#   Ubuntu 24.04
#   Rocky 8, 9
#   CentOS 8, 9
#   RHEL 8, 9
#
# Category: Monitoring
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @TRMM-TIMEOUT 120
#
# Requirements:
#   N/A
#
# TRMM Custom Fields:
#   site.graylog_server - Fully resolved URL of Graylog server, including http(s)://, port, and /api
#   site.graylog_token - API token for the Graylog server
#
#
# Changelog:
# 	2025.04.09 - Original Release
#


function usage() {
  cat >&2 <<EOD
Usage: $0 [options]

Options:
    --server=<string> - ... - Fully resolved URL of Graylog server, including http(s)://, port, and /api (REQUIRED)
    GRAYLOG_TOKEN (environmental variable) - API token for the Graylog server (REQUIRED)


EOD
  exit 1
}

# Parse arguments
SERVER=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--server=*)
			SERVER="${1#*=}";
			[ "${SERVER:0:1}" == "'" ] && [ "${SERVER:0-1}" == "'" ] && SERVER="${SERVER:1:-1}"
			[ "${SERVER:0:1}" == '"' ] && [ "${SERVER:0-1}" == '"' ] && SERVER="${SERVER:1:-1}"
			shift 1;;
		-h|--help) usage;;
	esac
done
if [ -z "$SERVER" ]; then
	usage
fi

##
# Simple check to enforce the script to be run as root
if [ $(id -u) -ne 0 ]; then
	echo "This script must be run as root or with sudo!" >&2
	exit 1
fi
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
# Check if the OS is "like" a certain type
#
# Returns 0 if true, 1 if false
#
# Usage:
#   if os_like debian; then ... ; fi
#
function os_like() {
	local OS="$1"

	if [ -f '/etc/os-release' ]; then
		ID="$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"
		LIKE="$(egrep '^ID_LIKE=' /etc/os-release | sed 's:ID_LIKE=::')"

		if [[ "$LIKE" =~ "$OS" ]] || [ "$ID" == "$OS" ]; then
			return 0;
		fi
	fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_debian)" -eq 1 ]; then ... ; fi
#   if os_like_debian -q; then ... ; fi
#
function os_like_debian() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like debian || os_like ubuntu; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_ubuntu)" -eq 1 ]; then ... ; fi
#   if os_like_ubuntu -q; then ... ; fi
#
function os_like_ubuntu() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like ubuntu; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_rhel)" -eq 1 ]; then ... ; fi
#   if os_like_rhel -q; then ... ; fi
#
function os_like_rhel() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like rhel || os_like fedora || os_like rocky || os_like centos; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_suse)" -eq 1 ]; then ... ; fi
#   if os_like_suse -q; then ... ; fi
#
function os_like_suse() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like suse; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_arch)" -eq 1 ]; then ... ; fi
#   if os_like_arch -q; then ... ; fi
#
function os_like_arch() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like arch; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_bsd)" -eq 1 ]; then ... ; fi
#   if os_like_bsd -q; then ... ; fi
#
function os_like_bsd() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if [ "$(uname -s)" == 'FreeBSD' ]; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	else
		if [ $QUIET -eq 0 ]; then echo 0; fi
		return 1
	fi
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_macos)" -eq 1 ]; then ... ; fi
#   if os_like_macos -q; then ... ; fi
#
function os_like_macos() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if [ "$(uname -s)" == 'Darwin' ]; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	else
		if [ $QUIET -eq 0 ]; then echo 0; fi
		return 1
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
#   2026.01.09 - Cleanup os_like a bit and add support for RHEL 9's dnf
#   2025.04.10 - Set Debian frontend to noninteractive
#
function package_install (){
	echo "package_install: Installing $*..."

	if os_like_bsd -q; then
		pkg install -y $*
	elif os_like_debian -q; then
		DEBIAN_FRONTEND="noninteractive" apt-get -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" install -y $*
	elif os_like_rhel -q; then
		if [ "$(os_version)" -ge 9 ]; then
			dnf install -y $*
		else
			yum install -y $*
		fi
	elif os_like_arch -q; then
		pacman -Syu --noconfirm $*
	elif os_like_suse -q; then
		zypper install -y $*
	else
		echo 'package_install: Unsupported or unknown OS' >&2
		echo 'Please report this at https://github.com/eVAL-Agency/ScriptsCollection/issues' >&2
		exit 1
	fi
}

if [ -z "$GRAYLOG_TOKEN" ]; then
	echo "ERROR - missing Graylog token in environment variable GRAYLOG_TOKEN" >&2
	exit 1
fi

if [ -z "$(which wget)" ]; then
	package_install wget
fi

SRC="https://packages.graylog2.org/repo/packages"

[ -e /opt/script-collection ] || mkdir -p /opt/script-collection

if [ $(os_like_debian) -eq 1 ]; then
	FILE="graylog-sidecar-repository_1-5_all.deb"

	if [ ! -e /opt/script-collection/$FILE ]; then
		wget $SRC/$FILE -O /opt/script-collection/$FILE
		if [ $? -ne 0 ]; then
			echo "Failed to download $SRC/$FILE" >&2
			exit 1
		fi

		export DEBIAN_FRONTEND="noninteractive"
		dpkg -i /opt/script-collection/$FILE
		apt-get update
		package_install graylog-sidecar
	fi
elif [ $(os_like_rhel) -eq 1 ]; then
	FILE="graylog-sidecar-repository-1-5.noarch.rpm"

	if [ ! -e /opt/script-collection/$FILE ]; then
		wget $SRC/$FILE -O /opt/script-collection/$FILE
		if [ $? -ne 0 ]; then
			echo "Failed to download $SRC/$FILE" >&2
			exit 1
		fi

		rpm -Uvh /opt/script-collection/$FILE
		dnf clean all
		package_install graylog-sidecar
	fi
elif [ $(os_like_suse) -eq 1 ]; then
	FILE="graylog-sidecar-repository-1-5.noarch.rpm"

	if [ ! -e /opt/script-collection/$FILE ]; then
		wget $SRC/$FILE -O /opt/script-collection/$FILE
		if [ $? -ne 0 ]; then
			echo "Failed to download $SRC/$FILE" >&2
			exit 1
		fi

		rpm -Uvh /opt/script-collection/$FILE
		mv /etc/yum.repos.d/* /etc/zypp/repos.d/
		zypper up
		package_install graylog-sidecar
	fi
else
	echo "Unable to install Graylog Sidecar, unsupported or unknown OS" >&2
	exit 1
fi


# Configure Graylog Sidecar
setconfigfile_orappend "^[#]?server_url:.*" "server_url: \"$SERVER\"" "/etc/graylog/sidecar/sidecar.yml"
setconfigfile_orappend "^[#]?server_api_token:.*" "server_api_token: \"$GRAYLOG_TOKEN\"" "/etc/graylog/sidecar/sidecar.yml"
setconfigfile_orappend "^[#]?node_name:.*" "node_name: \"$(hostname -f)\"" "/etc/graylog/sidecar/sidecar.yml"


# Install the systemd service
graylog-sidecar -service install
if [ $? -ne 0 ]; then
	# Failed to install the service, probably already installed.
	systemctl restart graylog-sidecar
else
	systemctl enable graylog-sidecar
    systemctl start graylog-sidecar
fi
