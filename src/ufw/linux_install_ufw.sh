#!/bin/bash
#
# Install Firewall (UFW)
#
# Install and enable the UFW firewall
#
# Supports:
#   Linux-All
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @CATEGORY Security
# @TRMM-TIMEOUT 60
#

# compile:usage
# compile:argparse
# scriptlet:_common/get_firewall.sh
# scriptlet:_common/package_remove.sh
# scriptlet:ufw/install.sh

if [ "$(get_available_firewall)" == "firewalld" ]; then
	package_remove firewalld
fi

install_ufw
