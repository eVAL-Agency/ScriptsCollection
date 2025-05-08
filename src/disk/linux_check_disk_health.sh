#!/bin/bash
#
# Check Disk Health [Linux]
#
# Uses smartctl to check physical disk health.
# If ZFS is installed, it will also check the health of the pools.
#
# Supports:
#   Debian-All
#   RHEL-All
#   Arch
#
# Category: Disks
#
# License:
#   AGPLv3
#
# Author:
#   Charlie Powell <cdp1337@veraciousnetwork.com>
#
# @TRMM-TIMEOUT 120
#
# Changelog:
#   20250507 - Fix support for Cisco Megaraid devices
#   20250204 - Skip smartctl check when no physical disks present, (VM)
#   20250130 - Change category to Disks
#            - Require root
#            - Add support for ZFS
#   20250106 - Initial version
#

# compile:usage
# compile:argparse
# scriptlet:_common/package_install.sh
# scriptlet:_common/require_root.sh

if [ -z "$(which smartctl)" ]; then
	package_install smartmontools
fi

EXIT=0
# Run smartctl to scan for physical disks
# excluding /dev/bus (to fix Cisco megaraid devices)
# skipping any comments (lines starting with #)
# and grab the first field (the device name)
for DISK in $(smartctl --scan | grep -v '/dev/bus/' | egrep -v '^#' | cut -d ' ' -f1); do
	echo "Disk $DISK"
	smartctl -H $DISK
	if [ $? -ne 0 ]; then
		EXIT=1
	fi
done

if [ -n "$(which zpool)" ]; then
	# ZFS is installed; check the health of the pools
	for POOL in $(zpool list -H -o name); do
		zpool status $POOL
		if [ "$(zpool list $POOL -H -o health)" != "ONLINE" ]; then
			EXIT=1
		fi
	done
fi

exit $EXIT
