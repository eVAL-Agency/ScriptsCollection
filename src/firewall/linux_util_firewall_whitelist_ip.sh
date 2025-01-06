#!/bin/bash
#
# Firewall - Whitelist IP
#
# Add an IP address to the firewall whitelist.
#
# Supports:
#   Linux-All
#
# Category:
#   User Management
#
# Syntax:
#   SOURCE=--ip=<ip>             IP address to whitelist (REQUIRED)
#   COMMENT=--comment=<comment>  Optional comment for the rule

# scriptlet:_common/get_firewall.sh
# scriptlet:_common/firewall_allow.sh
# compile:usage
# compile:argparse

FIREWALL_ENABLED="$(get_enabled_firewall)"

if [ "$FIREWALL_ENABLED" == "none" ]; then
	echo "No firewall enabled!" >&2
	exit 1
fi

firewall_allow --zone trusted --source "$SOURCE" --comment "$COMMENT"
