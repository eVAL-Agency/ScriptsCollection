#!/bin/bash
#
# Install GLPI Agent [Linux]
#
# Install the GLPI inventory agent
#
# Generated with info from
# https://glpi-agent.readthedocs.io/en/version-1.17/installation/index.html#linux-installer
#
# Syntax:
#   GLPI_SERVER=--server=<string> - Hostname or IP of GLIP server to push inventory to
#   VERSION=--version=<string> - Optional version to download; DEFAULT=latest
#   TAG=--tag=<string> - Tag is the Entity tag to associate with in GLPI
#
# TRMM Arguments:
#   --server={{client.glpi_hostname}}
#
# Supports:
#   Debian 12, 13
#   Ubuntu 24.04
#   Rocky 8, 9
#   CentOS 8, 9
#   RHEL 8, 9
#
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
#   2026.09.13 - Switch to using log_* functions
#   2026.07.01 - Initial release

# scriptlet:_common/require_root.sh
# scriptlet:_common/os_like.sh
# scriptlet:_common/download.sh
# scriptlet:bz_eval_log/log.sh

# compile:usage
# compile:argparse

if os_like_debian -q; then
	# Debian should ensure that apt is up to date, as IP addresses or hostnames may change.
	apt update;
fi

if [ "$VERSION" == "latest" ]; then
	# Use curl to check the latest version.
	VERSION="$(curl -s -o /dev/null -w "%{redirect_url}" https://github.com/glpi-project/glpi-agent/releases/latest)"
	VERSION="${VERSION##*/}"
fi

SRC="https://github.com/glpi-project/glpi-agent/releases/download/${VERSION}/glpi-agent-${VERSION}-linux-installer.pl"
FILE="glpi-agent-${VERSION}-linux-installer.pl"

# We will use this directory as a working directory for source files that need downloaded.
[ -d /opt/script-collection ] || mkdir -p /opt/script-collection

if ! download "$SRC" "/opt/script-collection/$FILE" --no-overwrite; then
	log_error "install_glpi_agent: Cannot download GLPI Agent from ${SRC}!"
	return 1
fi

perl /opt/script-collection/$FILE --no-question --server="$GLPI_SERVER" --tag="$TAG" --no-httpd --runnow