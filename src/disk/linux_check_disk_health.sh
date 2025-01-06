#!/bin/bash
#
# Disk Drive Health Check
#
# Uses smartctl to check physical disk health.
#
# Supports:
#   Debian-All
#   RHEL-All
#   Arch
#
# Category: Hardware
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @TRMM-TIMEOUT 120
#

# compile:usage
# compile:argparse
# scriptlet:_common/package_install.sh

if [ -z "$(which smartmontools)" ]; then
	package_install smartmontools
fi

EXIT=0
for DISK in $(sudo smartctl --scan | cut -d ' ' -f1); do
	sudo smartctl -H $DISK
	if [ $? -ne 0 ]; then
		EXIT=1
	fi
done

exit $EXIT
