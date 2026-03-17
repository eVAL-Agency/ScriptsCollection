#!/bin/bash
#
# Install Firewall (UFW) [Linux]
#
# Install and enable the UFW firewall
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
# @TRMM-TIMEOUT 60
#
# Changelog:
#   20250105 - Initial release
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
