#!/bin/bash
#
# Check if Reboot Required [Linux]
#
# Checks if this device requires a reboot.
#
# Supports:
#   Linux-All
#
# Category:
#   Updates
#
# License:
#   AGPLv3
#
# Author:
#   Charlie Powell <cdp1337@veraciousnetwork.com>

if [ -e /var/run/reboot-required ]; then
	cat /var/run/reboot-required

	if [ -e /var/run/reboot-required.pkgs ]; then
		cat /var/run/reboot-required.pkgs
	fi

	exit 1
fi

echo "Reboot not required"
exit 0
