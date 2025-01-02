#!/bin/bash
#
# Install Zabbix Agent2
#
# Please ensure to run this script as root (or at least with sudo)
#
# Generated with info from
# https://www.zabbix.com/download?zabbix=7.0&os_distribution=debian&os_version=12&components=agent_2&db=&ws=
#
#
# Arguments:
#   --noninteractive - Run in non-interactive mode, (will not ask for prompts)
#   --version=... - Version of Zabbix to install (default: 7.0)
#
# Environmental Variables:
#   ZABBIX_SERVER - Hostname or IP of Zabbix server
#   ZABBIX_AGENT_HOSTNAME - Hostname of local device for matching with a Zabbix host entry
#
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @CATEGORY System Monitoring
# @TRMM-TIMEOUT 120
# @SUPPORTS Debian 12
# @SUPPORTS Ubuntu 24.04
# @SUPPORTS Rocky 8, 9
# @SUPPORTS CentOS 8, 9
# @SUPPORTS RHEL 8, 9

# scriptlet:_common/require_root.sh
# scriptlet:zabbix/repo-setup.sh
# scriptlet:_common/package_install.sh
# scriptlet:_common/setconfigfile_orappend.sh
# scriptlet:_common/prompt_text.sh
# scriptlet:_common/print_header.sh

# Variable setup
VERSION="7.0"
ZABBIX_AGENT_CONFIGURATION="/etc/zabbix/zabbix_agent2.conf"
ZABBIX_AGENT_CONFIGURATION_EXTRAS="/etc/zabbix/zabbix_agent2.d"
NONINTERACTIVE=0

# Argument parsing
while [ "$#" -gt 0 ]; do
	case "$1" in
		--noninteractive) NONINTERACTIVE=1; shift 1;;
		--version=*) VERSION="${1#*=}"; shift 1;;
		#-p) pidfile="$2"; shift 2;;
		#-*) echo "unknown option: $1" >&2; exit 1;;
		#*) handle_argument "$1"; shift 1;;
	esac
done

if [ "$VERSION" == "latest" ]; then
	VERSION="7.2"
fi

# User prompts (if not in non-interactive mode)
if [ $NONINTERACTIVE -eq 0 ]; then
	ZABBIX_SERVER="$(prompt_text "Hostname or IP of Zabbix server")"
	ZABBIX_AGENT_HOSTNAME="$(prompt_text "Hostname of local device for matching with a Zabbix host entry" --default="$(hostname -f)")"
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
