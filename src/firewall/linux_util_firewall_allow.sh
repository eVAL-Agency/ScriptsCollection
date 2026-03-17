#!/bin/bash
#
# Firewall - Allow IP/Port [Linux]
#
# Allow a service in the firewall.
#
# Supports:
#   Linux-All
#
# Category:
#   Firewall
#
# Syntax:
#   SOURCE=--ip=<string>        IP address or CIDR network to allow DEFAULT=any
#   PORT=--port=<int>         Port(s) to allow (REQUIRED)
#   PROTO=--proto=<tcp|udp>    Protocol to allow DEFAULT=tcp
#   COMMENT=--comment=<comment>  Optional comment for the rule
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
#   2025.04.10 - Initial version

# scriptlet:_common/get_firewall.sh
# scriptlet:_common/firewall_allow.sh
# compile:usage
# compile:argparse

FIREWALL_ENABLED="$(get_enabled_firewall)"

if [ "$FIREWALL_ENABLED" == "none" ]; then
	echo "No firewall enabled!" >&2
	exit 1
fi

firewall_allow --port "$PORT" --proto "$PROTO" --source "$SOURCE" --comment "$COMMENT"
