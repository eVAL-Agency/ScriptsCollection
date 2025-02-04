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

# compile:usage
# compile:argparse
# scriptlet:_common/package_install.sh
# scriptlet:_common/require_root.sh

if [ -z "$(which smartctl)" ]; then
	package_install smartmontools
fi

EXIT=0
for DISK in $(smartctl --scan | egrep -v '^#' | cut -d ' ' -f1); do
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
