#!/bin/bash
#
# Install net-diag utilities
#
# Supports:
#   Linux-All
#
# Category:
#   Network Utility
#
# License:
#   AGPLv3
#
# Author:
#   Charlie Powell <cdp1337@veraciousnetwork.com>

##
# Simple check to enforce the script to be run as root
if [ $(id -u) -ne 0 ]; then
	echo "This script must be run as root or with sudo!" >&2
	exit 1
fi

RELEASE="$(curl -I https://github.com/eVAL-Agency/net-diag/releases/latest 2>&1 | egrep '^location' | sed 's:.*tag/\(v[0-9\.]*\).*:\1:')"
SRC="https://github.com/eVAL-Agency/net-diag/releases/download/${RELEASE}/net_diag-linux-$(uname -m)-${RELEASE}.tgz"
FILE="$(basename "$SRC")"

[ -d /opt/script-collection ] || mkdir -p /opt/script-collection

if [ ! -e /opt/script-collection/$FILE ]; then
	curl -L -o "/opt/script-collection/$FILE" "$SRC"
	if [ $? -ne 0 ]; then
		echo "Failed to download $SRC" >&2
		exit 1
	fi

	[ -d "/opt/script-collection/net-diag" ] || mkdir -p /opt/script-collection/net-diag
	tar -xzf /opt/script-collection/$FILE -C /opt/script-collection/net-diag

	[ -h /usr/local/bin/network_discover ] || ln -s /opt/script-collection/net-diag/network_discover /usr/local/bin/network_discover

	echo "Installed Net-diag $RELEASE in /opt/script-collection/net-diag"
else
	echo "Net-diag $RELEASE already exists: /opt/script-collection/net-diag"
fi
