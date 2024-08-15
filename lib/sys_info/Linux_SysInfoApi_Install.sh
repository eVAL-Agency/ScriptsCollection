#!/bin/bash
# Install Python and the sys_info_api library for use within TacticalRMM scripts.
#
# Supports:
#   Debian 10 - 12
#   Rocky Linux 8 - 9
#   Ubuntu 18.04 - 24.04
#
# Requirements:
#   None
#
# TRMM Custom Fields:
#   None
#
# Args:
#   None
#
# Environment Variables:
#   None
#
# License:
#   GNU Affero General Public License
#
# Author:
# 	Charlie Powell <cdp1337@veraciousnetwork.com>
#
# Changelog:
# 	2024.08.NN - Original Release
#


# Ensure the base directories exist for TRMM
if [ ! -d "/opt/tacticalagent/scripts" ]; then
	mkdir -p /opt/tacticalagent/scripts
fi
if [ ! -d "/opt/tacticalagent/toolbox" ]; then
	mkdir -p /opt/tacticalagent/toolbox
fi
if [ ! -d "/opt/tacticalagent/logs" ]; then
	mkdir -p /opt/tacticalagent/logs
fi
if [ ! -d "/opt/tacticalagent/temp" ]; then
	mkdir -p /opt/tacticalagent/temp
fi

# PIP is a requirement for this script; ensure that's setup.
if [ -z "$(which pip3)" ]; then
	if [ -n "$(which apt)" ]; then
		apt-get update
		apt-get install -y python3-pip
	elif [ -n "$(which yum)" ]; then
		yum install -y python3-pip
	else
		echo "Could not find a package manager to install python3-pip"
		exit 1
	fi
fi

# When in development, git is required.  This can be omitted once finalized.
if [ -z "$(which git)" ]; then
	if [ -n "$(which apt)" ]; then
		apt-get update
		apt-get install -y git
	elif [ -n "$(which yum)" ]; then
		yum install -y git
	else
		echo "Could not find a package manager to install git"
		exit 1
	fi
fi

# Install the sys_info_api library in TacticalRMM
python3 -m venv /opt/tacticalagent/toolbox/sys_info_api
/opt/tacticalagent/toolbox/sys_info_api/bin/pip install --upgrade --force-reinstall git+https://github.com/cdp1337/sys-info-api.git