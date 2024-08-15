#!/bin/bash
# Some description of this script, what it does, and how it works.
#
# Supports:
#   List of operating systems this script supports and their versions
#   Feel free to adjust as necessary, no strict format requirements,
#   just should be useful to the end sysadmin.
#   Alma Linux n - n
#   CentOS n - n
#   Debian n - n
#   Fedora n - n
#   FreeBSD n - n
#   MacOS n - n
#   OpenSuSE n - n
#   Rocky Linux n - n
#   SLES n - n
#   Ubuntu n - n
#   Windows n - n
#   Windows Server n - n
#
# Requirements:
#   None | List of requirements / dependencies
#
# TRMM Custom Fields:
#   None | List of custom fields that should be present in TRMM
#   client.some_client_level_field - Some field that should be set at the client level
#   site.some_site_level_field - Some field that should be set at the site level
#   agent.some_agent_level_field - Some field that should be set at the agent level
#
# Args:
#   None | List of arguments that can be passed to the script
#
# Environment Variables:
#   None | List of environment variables that can be set to adjust the behavior of the script
#
# License:
#   name-of-your-license-here
#
# Author:
# 	Your name, email, and/or contact info
#
# Changelog:
# 	YYYY.MM.DD - Original Release
#   or whatever format you would like to use for indicating changes throughout the life of the script.
#


# Your script here
# Refer to https://docs.tacticalrmm.com/contributing_community_scripts/
# for guidelines when writing scripts.
#
# A few general blocks of code are provided, but feel free to remove them if they are not needed.


# The following directories are useful for standardized items such as temp downloads and the like.
# Feel free to remove the directives that do not apply to your script.
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


# Need pip?
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


# Need git?
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


# Need to deploy a new pip tool in the toolkit?
python3 -m venv /opt/tacticalagent/toolbox/name-of-tool
/opt/tacticalagent/toolbox/name-of-tool/bin/pip install --upgrade --force-reinstall name-of-tool