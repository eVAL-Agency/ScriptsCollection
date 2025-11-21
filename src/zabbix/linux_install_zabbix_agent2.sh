#!/bin/bash
#
# Install Zabbix Agent2 [Linux]
#
# Please ensure to run this script as root (or at least with sudo)
#
# Generated with info from
# https://www.zabbix.com/download?zabbix=7.0&os_distribution=debian&os_version=12&components=agent_2&db=&ws=
#
#
# Syntax:
#   NONINTERACTIVE=--noninteractive - Run in non-interactive mode, (will not ask for prompts)
#   VERSION=--version=<string> - Version of Zabbix to install (5.0|6.0|7.0|latest) DEFAULT=7.0
#   ZABBIX_SERVER=--server=<string> - Hostname or IP of Zabbix server (optional unless non-interactive)
#   ZABBIX_AGENT_HOSTNAME=--hostname=<string> - Hostname of local device for matching with a Zabbix host entry (optional unless non-interactive)
#
# TRMM Arguments:
#   --noninteractive
#   --version=7.0
#   --server={{client.zabbix_hostname}}
#   --hostname={{agent.fqdn}}
#
# Supports:
#   Debian 12
#   Ubuntu 24.04
#   Rocky 8, 9
#   CentOS 8, 9
#   RHEL 8, 9
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @CATEGORY Monitoring
# @TRMM-TIMEOUT 120
#
# Changelog:
#   20250130 - Change category to Monitoring
#   20250101 - Initial release

# scriptlet:_common/require_root.sh
# scriptlet:zabbix/repo-setup.sh
# scriptlet:_common/package_install.sh
# scriptlet:_common/setconfigfile_orappend.sh
# scriptlet:_common/prompt_text.sh
# scriptlet:_common/print_header.sh

# Variable setup
ZABBIX_AGENT_CONFIGURATION="/etc/zabbix/zabbix_agent2.conf"
ZABBIX_AGENT_CONFIGURATION_EXTRAS="/etc/zabbix/zabbix_agent2.d"

# compile:usage
# compile:argparse

if [ "$VERSION" == "latest" ]; then
	VERSION="7.2"
fi

# User prompts (if not in non-interactive mode)
if [ $NONINTERACTIVE -eq 0 ]; then
	if [ -z "$ZABBIX_SERVER" ]; then
		ZABBIX_SERVER="$(prompt_text "Hostname or IP of Zabbix server")"
	fi
	if [ -z "$ZABBIX_AGENT_HOSTNAME" ]; then
		ZABBIX_AGENT_HOSTNAME="$(prompt_text "Hostname of local device for matching with a Zabbix host entry" --default="$(hostname -f)")"
	fi
else
	if [ -z "$ZABBIX_SERVER" ]; then
    	usage
	fi
	if [ -z "$ZABBIX_AGENT_HOSTNAME" ]; then
		usage
	fi
fi

# Setup Zabbix repo
zabbix_repo_setup "$VERSION"

# Install the agent
package_install "zabbix-agent2" "zabbix-agent2-plugin-*"

# Ensure the extra defines directory exists
[ -d "$ZABBIX_AGENT_CONFIGURATION_EXTRAS" ] || mkdir -p "$ZABBIX_AGENT_CONFIGURATION_EXTRAS"

# Setup config from user-definable parameters
setconfigfile_orappend "^Server=.*" "Server=${ZABBIX_SERVER}" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^ServerActive=.*" "ServerActive=${ZABBIX_SERVER}" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^Hostname=.*" "Hostname=${ZABBIX_AGENT_HOSTNAME}" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^Include=${ZABBIX_AGENT_CONFIGURATION_EXTRAS}/\*\.conf" "Include=${ZABBIX_AGENT_CONFIGURATION_EXTRAS}/*.conf" "$ZABBIX_AGENT_CONFIGURATION"

# Restart and enable the service
systemctl restart zabbix-agent2
systemctl enable zabbix-agent2

print_header 'Zabbix agent2 installed'
echo "Agent Version:   $VERSION"
echo "Zabbix Server:   $ZABBIX_SERVER"
echo "Device Hostname: $ZABBIX_AGENT_HOSTNAME"
echo ''
echo 'If you have not done so already, please create a new Host in Zabbix for this device.'
