#!/bin/bash
#
# Firewall - Check Status [Linux]
#
# Check the status of the firewall on a Linux system and print any rules defined.
#
# Supports:
#   Linux-All
#
# Category:
#   Security
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
# Changelog:
#   20250105 - Initial version

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
# Get which firewall is enabled or "none" if none currently active
#
# CHANGELOG:
#   2026.09.16 - Add support for ProxmoxVE Firewall
#
function get_enabled_firewall() {
	if [ "$(systemctl is-active firewalld)" == "active" ]; then
		echo "firewalld"
	elif [ "$(systemctl is-active ufw)" == "active" ]; then
		echo "ufw"
	elif cmd_exists pvesh && [ "$(pve-firewall status)" == "Status: enabled/running" ]; then
		echo "proxmox"
	elif [ "$(systemctl is-active iptables)" == "active" ]; then
		echo "iptables"
	else
		echo "none"
	fi
}

##
# Get which firewall is available on the local system or "none" if none located
#
# CHANGELOG:
#   2026.09.16 - Add support for ProxmoxVE Firewall
#   2025.12.15 - Use cmd_exists to fix regression bug
#   2025.04.10 - Switch from "systemctl list-unit-files" to "which" to support older systems
#
function get_available_firewall() {
	if cmd_exists firewall-cmd; then
		echo "firewalld"
	elif cmd_exists ufw; then
		echo "ufw"
	elif cmd_exists pvesh; then
	   echo "proxmox"
	elif cmd_exists iptables; then
		echo "iptables"
	else
		echo "none"
	fi
}

FIREWALL_AVAILABLE="$(get_available_firewall)"
FIREWALL_ENABLED="$(get_enabled_firewall)"

if [ "$FIREWALL_AVAILABLE" == "none" ]; then
	echo "No firewall installed"
	exit 1
fi

if [ "$FIREWALL_ENABLED" == "none" ]; then
	echo "Firewall: $FIREWALL_AVAILABLE - Status: Disabled"
	exit 1
elif [ "$FIREWALL_ENABLED" != "$FIREWALL_AVAILABLE" ]; then
	echo "WARNING - Firewall $FIREWALL_AVAILABLE installed but $FIREWALL_ENABLED is enabled"
	exit 1
else
	echo "Firewall: $FIREWALL_AVAILABLE - Status: Enabled"
fi


case "$FIREWALL_ENABLED" in
	"ufw")
		ufw status verbose
		;;
	"firewalld")
		for ZONE in $(firewall-cmd --get-zones); do
    		firewall-cmd --list-all --zone=$ZONE
    	done
    	;;
 	"proxmox" | "iptables")
 		iptables -L -v -n
 		;;
esac
