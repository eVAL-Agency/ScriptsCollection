#!/bin/bash
#
# Install Zabbix Proxy
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
# scriptlet:_common/random_password.sh
# scriptlet:_common/os_like.sh

# Variable setup
VERSION="7.0"
ZABBIX_AGENT_CONFIGURATION="/etc/zabbix/zabbix_proxy.conf"
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

# Install the proxy
package_install zabbix-proxy-mysql zabbix-sql-scripts
if [ $(os_like_rhel) -eq 1 ]; then
	package_install zabbix-selinux-policy
fi


# Setup config from user-definable parameters
setconfigfile_orappend "^Server=.*" "Server=${ZABBIX_SERVER}" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^Hostname=.*" "Hostname=${ZABBIX_AGENT_HOSTNAME}" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^EnableRemoteCommands=.*" "EnableRemoteCommands=1" "$ZABBIX_AGENT_CONFIGURATION"
setconfigfile_orappend "^AllowUnsupportedDBVersions=.*" "AllowUnsupportedDBVersions=1" "$ZABBIX_AGENT_CONFIGURATION"

# If no password has been set, presume that Zabbix isn't configured yet.
if grep -q '# DBPassword=' /etc/zabbix/zabbix_proxy.conf; then
	# Generate a random password for Zabbix
	DBPASS="$(random_password)"
	mysql -e "create database zabbix_proxy character set utf8mb4 collate utf8mb4_bin"
	mysql -e "create user zabbix@localhost identified by '$DBPASS'"
	mysql -e "grant all privileges on zabbix_proxy.* to zabbix@localhost"
	mysql -e "set global log_bin_trust_function_creators = 1"

	# Install the initial data
	cat /usr/share/zabbix-sql-scripts/mysql/proxy.sql | mysql --default-character-set=utf8mb4 zabbix_proxy

	# Disable log_bin_trust_function_creators option after importing database schema.
	mysql -e "set global log_bin_trust_function_creators = 0"

	# Set the password in Zabbix's config file
	sed -i "s/# DBPassword=/DBPassword=$DBPASS/g" /etc/zabbix/zabbix_proxy.conf
fi

# Restart and enable the service
systemctl restart zabbix-proxy
systemctl enable zabbix-proxy

print_header 'Zabbix proxy installed'
echo "Agent Version:   $VERSION"
echo "Zabbix Server:   $ZABBIX_SERVER"
echo "Device Hostname: $ZABBIX_AGENT_HOSTNAME"
echo ''
echo 'If you have not done so already, please create a new Proxy in Zabbix for this device.'
echo '(Administration -> Proxies -> Create Proxy)'
echo ''
echo 'Followed by setting its IP range and checks enabled'
echo '(Data collection -> Discovery)'
