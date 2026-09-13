#!/bin/bash
#
# Install Graylog Sidecar [Linux]
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
# TRMM Custom Fields:
#   site.graylog_server - Fully resolved URL of Graylog server, including http(s)://, port, and /api
#   site.graylog_token - API token for the Graylog server
#
# Supports:
#   Debian 12, 13
#   Ubuntu 24.04
#   Rocky 8, 9
#   CentOS 8, 9
#   RHEL 8, 9
#
# Category:
#   Monitoring
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
# @TRMM-TIMEOUT 120
#
# Changelog:
#   2026.09.13 - Switch to using log_* functions for messages
#              - Switch to using download function for downloading
#   2026.04.08 - Bump Graylog repo version to 1.6
# 	2025.04.09 - Original Release
#


# compile:usage
# compile:argparse
# scriptlet:_common/require_root.sh
# scriptlet:_common/setconfigfile_orappend.sh
# scriptlet:_common/os_like.sh
# scriptlet:_common/package_install.sh
# scriptlet:_common/download.sh
# scriptlet:bz_eval_log/log.sh

if [ -z "$GRAYLOG_TOKEN" ]; then
	log_error "Missing Graylog token in environment variable GRAYLOG_TOKEN"
	exit 1
fi

SRC="https://downloads.graylog.org/repo/packages"

[ -e /opt/script-collection ] || mkdir -p /opt/script-collection

if os_like_debian -q; then
	FILE="graylog-sidecar-repository_1-6_all.deb"

	if ! download "$SRC/$FILE" "/opt/script-collection/$FILE" --no-overwrite; then
		log_error "Failed to download $SRC/$FILE"
		exit 1
	fi

	export DEBIAN_FRONTEND="noninteractive"
	dpkg -i /opt/script-collection/$FILE
	package_install graylog-sidecar
elif os_like_rhel -q; then
	FILE="graylog-sidecar-repository-1-6.noarch.rpm"

	if ! download "$SRC/$FILE" "/opt/script-collection/$FILE" --no-overwrite; then
		log_error "Failed to download $SRC/$FILE"
		exit 1
	fi

	rpm -Uvh /opt/script-collection/$FILE
	package_install graylog-sidecar
elif os_like_suse -q; then
	FILE="graylog-sidecar-repository-1-6.noarch.rpm"

	if ! download "$SRC/$FILE" "/opt/script-collection/$FILE" --no-overwrite; then
		log_error "Failed to download $SRC/$FILE"
		exit 1
	fi

	rpm -Uvh /opt/script-collection/$FILE
	mv /etc/yum.repos.d/* /etc/zypp/repos.d/
	package_install graylog-sidecar
else
	log_error "Unable to install Graylog Sidecar, unsupported or unknown OS"
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
