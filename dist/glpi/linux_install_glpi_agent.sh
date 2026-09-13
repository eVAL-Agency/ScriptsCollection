#!/bin/bash
#
# Install GLPI Agent [Linux]
#
# Install the GLPI inventory agent
#
# Generated with info from
# https://glpi-agent.readthedocs.io/en/version-1.17/installation/index.html#linux-installer
#
# Syntax:
#   --server=<string> - Hostname or IP of GLIP server to push inventory to
#   --version=<string> - Optional version to download; DEFAULT=latest
#   --tag=<string> - Tag is the Entity tag to associate with in GLPI
#
# TRMM Arguments:
#   --server={{client.glpi_hostname}}
#
# Supports:
#   Debian 12, 13
#   Ubuntu 24.04
#   Rocky 8, 9
#   CentOS 8, 9
#   RHEL 8, 9
#
#
# Category:
#   Monitoring
#
# License:
#   AGPLv3
#
# Author:
#   Charlie Powell <cdp1337@bitsnbytes.dev>
#
# Link:
#   https://github.com/eVAL-Agency/ScriptsCollection
#
# @TRMM-TIMEOUT 120
#
# Changelog:
#   2026.09.13 - Switch to using log_* functions
#   2026.07.01 - Initial release

##
# Simple check to enforce the script to be run as root
if [ $(id -u) -ne 0 ]; then
	echo "This script must be run as root or with sudo!" >&2
	exit 1
fi
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
		ID="$(grep -E '^ID=' /etc/os-release | sed 's:ID=::')"
		LIKE="$(grep -E '^ID_LIKE=' /etc/os-release | sed 's:ID_LIKE=::')"

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
# Simple wrapper to emulate `which -s`
#
# The -s flag is not available on all systems, so this function
# provides a consistent way to check for command existence
# without having to include '&>/dev/null' everywhere.
#
# Returns 0 on success, 1 on failure
#
# Arguments:
#   $1 - Command to check
#
# CHANGELOG:
#   2025.12.15 - Initial version (for a regression fix)
#
function cmd_exists() {
	local CMD="$1"
	which "$CMD" &>/dev/null
	return $?
}
##
# log helper by eval.bz
#
# Facilitates a basic logging system for Bash to print messages to stderr
#
# Using:
#
# Include this file (or however your import system works)
# # scriptlet: bz_eval_log/log.sh
#
# Change logging level
# LOG_LEVEL=3 - Set logging level to DEBUG so all messages are displayed
# LOG_LEVEL=2 - (DEFAULT) - Set logging to info, warnings, and errors
# LOG_LEVEL=1 - Only display warnings and errors
# LOG_LEVEL=0 - Only display errors
#
# Disable coloration
# By default this script renders messages with colors.  Disable this with the following
# LOG_COLORS=0
#
# Logging messages
# log_debug "This is a debug statement"
# log_info "This is an informational statement"
# log_warning "This is a warning message"
# log_error "This is an error message"
#

# Set the verbosity level: 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG
LOG_LEVEL=${LOG_LEVEL:-2}

# Set to '0' to disable ANSI colors
LOG_COLORS=1

# ANSI Color Codes
LOG_RED='\033[0;31m'
LOG_GREEN='\033[0;32m'
LOG_YELLOW='\033[1;33m'
LOG_BLUE='\033[0;34m'
LOG_NC='\033[0m' # No Color

##
# Print a header message
#
# CHANGELOG:
#   2026.04.30 - Initial version
#
function bz_eval_log() {
    local level_name="$1"
    local color
    local message="$2"
    local numeric_level=0

    # Map level names to numbers for comparison
    case "${level_name^^}" in
        "ERROR") numeric_level=0; color="$LOG_RED" ;;
        "WARN")  numeric_level=1; color="$LOG_YELLOW" ;;
        "INFO")  numeric_level=2; color="" ;;
        "DEBUG") numeric_level=3; color="$LOG_BLUE" ;;
    esac

    # Only print if the current log level is high enough
    if [ "$numeric_level" -le "$LOG_LEVEL" ]; then
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        # Print to stderr (&2)
        if [ $LOG_COLORS -eq 1 ] && [ "$color" != "" ]; then
        	printf "${color}[%s] [%s] %s${LOG_NC}\n" "$timestamp" "$level_name" "$message" >&2
		else
        	printf "[%s] [%s] %s\n" "$timestamp" "$level_name" "$message" >&2
        fi
    fi
}

# Helper wrappers for convenience
function log_error()   { bz_eval_log "ERROR" "$1"; }
function log_warning() { bz_eval_log "WARN"  "$1"; }
function log_info()    { bz_eval_log "INFO"  "$1"; }
function log_debug()   { bz_eval_log "DEBUG" "$1"; }

##
# Simple download utility function
#
# Uses either cURL or wget based on which is available
#
# Downloads the file to a temp location initially, then moves it to the final destination
# upon a successful download to avoid partial files.
#
# Returns 0 on success, 1 on failure
#
# Arguments:
#   --no-overwrite       Skip download if destination file already exists
#
# Examples:
#
# Download URL to local file
#   download "https://example.tld/file.dat" "file.dat"
#
# Test downloading was successful
#   if download "https://example.tld/file.dat" "file.dat"; then
#     # download was successful; do some operation
#   fi
#
# CHANGELOG:
#   2026.04.30 - Use logging with new logging interface
#   2026.04.21 - Add retry in curl to retry on connection issues, (looking at you Github)
#   2025.12.15 - Use cmd_exists to fix regression bug
#   2025.12.04 - Add --no-overwrite option to allow skipping download if the destination file exists
#   2025.11.23 - Download to a temp location to verify download was successful
#              - use which -s for cleaner checks
#   2025.11.09 - Initial version
#
function download() {
	# Argument parsing
	local SOURCE="$1"
	local DESTINATION="$2"
	local OVERWRITE=1
	local TMP=$(mktemp)
	shift 2

	while [ $# -ge 1 ]; do
		case $1 in
			--no-overwrite)
				OVERWRITE=0
				;;
		esac
		shift
	done

	if [ -z "$SOURCE" ] || [ -z "$DESTINATION" ]; then
		log_error "download: Missing required parameters!"
		return 1
	fi

	if [ -f "$DESTINATION" ] && [ $OVERWRITE -eq 0 ]; then
		log_info "download: Destination file $DESTINATION already exists, skipping download."
		return 0
	fi

	if cmd_exists curl; then
		log_debug "download: Attempting to curl download $SOURCE"
		if curl --connect-timeout 10 --retry 3 --retry-delay 10 -fsL "$SOURCE" -o "$TMP"; then
			log_debug "download: Download successful, moving file to $DESTINATION"
			mv $TMP "$DESTINATION"
			return 0
		else
			log_error "download: curl failed to download $SOURCE"
			return 1
		fi
	elif cmd_exists wget; then
		log_debug "download: Attempting to wget download $SOURCE"
		if wget -q "$SOURCE" -O "$TMP"; then
			log_debug "download: Download successful, moving file to $DESTINATION"
			mv $TMP "$DESTINATION"
			return 0
		else
			log_error "download: wget failed to download $SOURCE"
			return 1
		fi
	else
		log_error "download: Neither curl nor wget is installed, cannot download!"
		return 1
	fi
}

function usage() {
  cat >&2 <<EOD
Usage: $0 [options]

Options:
    --server=<string> - Hostname or IP of GLIP server to push inventory to
    --version=<string> - Optional version to download; DEFAULT=latest
    --tag=<string> - Tag is the Entity tag to associate with in GLPI

Install the GLPI inventory agent

Generated with info from
https://glpi-agent.readthedocs.io/en/version-1.17/installation/index.html#linux-installer
EOD
  exit 1
}

# Parse arguments
GLPI_SERVER=""
VERSION="latest"
TAG=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--server=*|--server)
			[ "$1" == "--server" ] && shift 1 && GLPI_SERVER="$1" || GLPI_SERVER="${1#*=}"
			[ "${GLPI_SERVER:0:1}" == "'" ] && [ "${GLPI_SERVER:0-1}" == "'" ] && GLPI_SERVER="${GLPI_SERVER:1:-1}"
			[ "${GLPI_SERVER:0:1}" == '"' ] && [ "${GLPI_SERVER:0-1}" == '"' ] && GLPI_SERVER="${GLPI_SERVER:1:-1}"
			;;
		--version=*|--version)
			[ "$1" == "--version" ] && shift 1 && VERSION="$1" || VERSION="${1#*=}"
			[ "${VERSION:0:1}" == "'" ] && [ "${VERSION:0-1}" == "'" ] && VERSION="${VERSION:1:-1}"
			[ "${VERSION:0:1}" == '"' ] && [ "${VERSION:0-1}" == '"' ] && VERSION="${VERSION:1:-1}"
			;;
		--tag=*|--tag)
			[ "$1" == "--tag" ] && shift 1 && TAG="$1" || TAG="${1#*=}"
			[ "${TAG:0:1}" == "'" ] && [ "${TAG:0-1}" == "'" ] && TAG="${TAG:1:-1}"
			[ "${TAG:0:1}" == '"' ] && [ "${TAG:0-1}" == '"' ] && TAG="${TAG:1:-1}"
			;;
		-h|--help) usage;;
		*) echo "Unknown argument: $1" >&2; usage;;
	esac
	shift 1
done
if [ -z "$GLPI_SERVER" ]; then
	usage
fi
if [ -z "$TAG" ]; then
	usage
fi


if os_like_debian -q; then
	# Debian should ensure that apt is up to date, as IP addresses or hostnames may change.
	apt update;
fi

if [ "$VERSION" == "latest" ]; then
	# Use curl to check the latest version.
	VERSION="$(curl -s -o /dev/null -w "%{redirect_url}" https://github.com/glpi-project/glpi-agent/releases/latest)"
	VERSION="${VERSION##*/}"
fi

SRC="https://github.com/glpi-project/glpi-agent/releases/download/${VERSION}/glpi-agent-${VERSION}-linux-installer.pl"
FILE="glpi-agent-${VERSION}-linux-installer.pl"

# We will use this directory as a working directory for source files that need downloaded.
[ -d /opt/script-collection ] || mkdir -p /opt/script-collection

if ! download "$SRC" "/opt/script-collection/$FILE" --no-overwrite; then
	log_error "install_glpi_agent: Cannot download GLPI Agent from ${SRC}!"
	return 1
fi

perl /opt/script-collection/$FILE --no-question --server="$GLPI_SERVER" --tag="$TAG" --no-httpd --runnow