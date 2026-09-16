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

# scriptlet:_common/get_firewall.sh

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
