#!/bin/bash
#
# Firewall - Allow IP/Port [Linux]
#
# Allow a service and/or source in the firewall.
#
# Examples:
#   Allow http/https - linux_util_firewall_allow.sh --port="80,443"
#   Allow DNS - linux_util_firewall_allow.sh --port=53 --proto=udp
#   Whitelist IP - linux_util_firewall_allow.sh --ip=5.4.5.4
#   Allow IP to access port - linux_util_firewall_allow.sh --ip=5.4.5.4 --port=22
#
# Supports:
#   Linux-All
#
# Category:
#   Security
#
# Syntax:
#   SOURCE=--ip=<string>        IP address or CIDR network to allow DEFAULT=""
#   PORT=--port=<string>         Port(s) to allow DEFAULT=""
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
#   2026.09.16 - Add support for ProxmoxVE Firewall
#   2026.09.15 - Retool to use firewall_action and auto-install the system firewall if necessary
#   2025.04.10 - Initial version

# scriptlet:_common/get_firewall.sh
# scriptlet:_common/firewall_action.sh
# scriptlet:_common/firewall_install.sh
# scriptlet:_common/require_root.sh
# scriptlet:bz_eval_log/log.sh
# compile:usage
# compile:argparse

# Ensure dependencies are installed
firewall_install

FIREWALL_AVAILABLE="$(get_available_firewall)"
if [ "$FIREWALL_AVAILABLE" == "none" ]; then
	log_error "Firewall auto-install failed"
	exit 1
fi

firewall_action --action allow --port "$PORT" --source "$SOURCE" --comment "$COMMENT"
