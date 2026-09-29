#!/bin/bash
#
# Switch Repo to Community [Proxmox]
#
# Supports:
#   Proxmox
#
# Category:
#   Repo
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
#   2026.09.29 - Add support for Proxmox 9.2
#   2025.05.02 - Initial version

##
# Get the operating system codename
#
# This returns the name of the os, generally used in repositories
#
# Debian may return "trixie" or "bullseye".
#
function os_codename() {
	if [ -f '/etc/os-release' ]; then
		local VERS="$(grep -E '^VERSION_CODENAME=' /etc/os-release | sed 's:VERSION_CODENAME=::')"

		if [[ "$VERS" =~ '"' ]]; then
			# Strip quotes around the OS codename
			VERS="$(echo "$VERS" | sed 's:"::g')"
		fi

		echo "$VERS"

	else
		echo ''
	fi
}

DISTRO="$(os_codename)"
if [ -e "/etc/apt/sources.list.d/debian.sources" ]; then
	FORMAT="sources"
else
	FORMAT="list"
fi

# Disable enterprise repos first
if [ -e "/etc/apt/sources.list.d/pve-enterprise.list" ]; then
	echo "Disabling pve-enterprise.list"
	mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.disabled
fi
if [ -e "/etc/apt/sources.list.d/pve-enterprise.sources" ]; then
	echo "Disabling pve-enterprise.sources"
	mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.disabled
fi

if [ -e "/etc/apt/sources.list.d/ceph.list" ]; then
	echo "Disabling ceph.list"
	mv /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph-enterprise.disabled
fi
if [ -e "/etc/apt/sources.list.d/ceph.sources" ]; then
	echo "Disabling ceph.sources"
	mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph-enterprise.disabled
fi


# Enable community repos
if [ -e "/etc/apt/sources.list.d/pve-community.disabled" ]; then
	echo "Enabling pve-community.${FORMAT}"
	mv /etc/apt/sources.list.d/pve-community.disabled /etc/apt/sources.list.d/pve-community.${FORMAT}
else
	echo "Creating pve-community.${FORMAT}"
	if [ "$FORMAT" == "sources" ]; then
		cat > /etc/apt/sources.list.d/pve-community.${FORMAT} <<EOD
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $DISTRO
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOD
	else
		echo "deb http://download.proxmox.com/debian/pve $DISTRO pve-no-subscription" > /etc/apt/sources.list.d/pve-community.list
	fi
fi

if [ -e "/etc/apt/sources.list.d/ceph-community.disabled" ]; then
	echo "Enabling ceph-community.${FORMAT}"
	mv /etc/apt/sources.list.d/ceph-community.disabled /etc/apt/sources.list.d/ceph-community.${FORMAT}
else
	echo "Creating ceph-community.${FORMAT}"
	if [ "$FORMAT" == "sources" ]; then
		cat > /etc/apt/sources.list.d/ceph-community.${FORMAT} <<EOD
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: $DISTRO
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOD
	else
		echo "deb http://download.proxmox.com/debian/ceph-quincy $DISTRO no-subscription" > /etc/apt/sources.list.d/ceph-community.list
	fi
fi

# Update repos
apt update
if [ $? -ne 0 ]; then
	echo "Failed to update apt repositories" >&2
	exit 1
fi