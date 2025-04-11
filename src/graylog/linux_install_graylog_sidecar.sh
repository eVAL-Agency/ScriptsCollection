#!/bin/bash
#
# Install Graylog Sidecar [Linux]
#
#
# Syntax:
#   SERVER=--server=... - Fully resolved URL of Graylog server, including http(s)://, port, and /api (REQUIRED)
#   GRAYLOG_TOKEN (environmental variable) - API token for the Graylog server (REQUIRED)
#
# TRMM Arguments:
#   --server={{client.graylog_server}}
#
# TRMM Environment:
#   GRAYLOG_TOKEN={{client.graylog_token}}
#
# Supports:
#   Debian 12
#   Ubuntu 24.04
#   Rocky 8, 9
#   CentOS 8, 9
#   RHEL 8, 9
#
# Category: Monitoring
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @TRMM-TIMEOUT 120
#
# Requirements:
#   N/A
#
# TRMM Custom Fields:
#   site.graylog_server - Fully resolved URL of Graylog server, including http(s)://, port, and /api
#   site.graylog_token - API token for the Graylog server
#
#
# Changelog:
# 	2025.04.09 - Original Release
#


# compile:usage
# compile:argparse
# scriptlet:_common/require_root.sh
# scriptlet:_common/setconfigfile_orappend.sh
# scriptlet:_common/os_like.sh
# scriptlet:_common/package_install.sh

if [ -z "$GRAYLOG_TOKEN" ]; then
	echo "ERROR - missing Graylog token in environment variable GRAYLOG_TOKEN" >&2
	exit 1
fi

if [ -z "$(which wget)" ]; then
	package_install wget
fi

SRC="https://packages.graylog2.org/repo/packages"

[ -e /opt/script-collection ] || mkdir -p /opt/script-collection

if [ $(os_like_debian) -eq 1 ]; then
	FILE="graylog-sidecar-repository_1-5_all.deb"

	if [ ! -e /opt/script-collection/$FILE ]; then
		wget $SRC/$FILE -O /opt/script-collection/$FILE
		if [ $? -ne 0 ]; then
			echo "Failed to download $SRC/$FILE" >&2
			exit 1
		fi

		export DEBIAN_FRONTEND="noninteractive"
		dpkg -i /opt/script-collection/$FILE
		apt-get update
		package_install graylog-sidecar
	fi
elif [ $(os_like_rhel) -eq 1 ]; then
	FILE="graylog-sidecar-repository-1-5.noarch.rpm"

	if [ ! -e /opt/script-collection/$FILE ]; then
		wget $SRC/$FILE -O /opt/script-collection/$FILE
		if [ $? -ne 0 ]; then
			echo "Failed to download $SRC/$FILE" >&2
			exit 1
		fi

		rpm -Uvh /opt/script-collection/$FILE
		dnf clean all
		package_install graylog-sidecar
	fi
elif [ $(os_like_suse) -eq 1 ]; then
	FILE="graylog-sidecar-repository-1-5.noarch.rpm"

	if [ ! -e /opt/script-collection/$FILE ]; then
		wget $SRC/$FILE -O /opt/script-collection/$FILE
		if [ $? -ne 0 ]; then
			echo "Failed to download $SRC/$FILE" >&2
			exit 1
		fi

		rpm -Uvh /opt/script-collection/$FILE
		mv /etc/yum.repos.d/* /etc/zypp/repos.d/
		zypper up
		package_install graylog-sidecar
	fi
else
	echo "Unable to install Graylog Sidecar, unsupported or unknown OS" >&2
	exit 1
fi


# Configure Graylog Sidecar
setconfigfile_orappend "^[#]?server_url:.*" "server_url: \"$SERVER\"" "/etc/graylog/sidecar/sidecar.yml"
setconfigfile_orappend "^[#]?server_api_token:.*" "server_api_token: \"$GRAYLOG_TOKEN\"" "/etc/graylog/sidecar/sidecar.yml"
setconfigfile_orappend "^[#]?node_name:.*" "node_name: \"$(hostname -f)\"" "/etc/graylog/sidecar/sidecar.yml"


# Install the systemd service
graylog-sidecar -service install
if [ $? -ne 0 ]; then
	# Failed to install the service, probably already installed.
	systemctl restart graylog-sidecar
else
	systemctl enable graylog-sidecar
    systemctl start graylog-sidecar
fi
