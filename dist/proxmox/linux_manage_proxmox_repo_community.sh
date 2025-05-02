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
#   Charlie Powell <cdp1337@veraciousnetwork.com>
#
# Changelog:
#   20250502 - Initial version


DISTRO="$(egrep '^VERSION_CODENAME' /etc/os-release | awk -F '=' '{print $2}')"

# Disable enterprise repos first
if [ -e "/etc/apt/sources.list.d/pve-enterprise.list" ]; then
	echo "Disabling pve-enterprise.list"
	mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.disabled
fi

if [ -e "/etc/apt/sources.list.d/ceph.list" ]; then
	echo "Disabling ceph.list"
	mv /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph-enterprise.disabled
fi


# Enable community repos
if [ -e "/etc/apt/sources.list.d/pve-community.disabled" ]; then
	echo "Enabling pve-community.list"
	mv /etc/apt/sources.list.d/pve-community.disabled /etc/apt/sources.list.d/pve-community.list
else
	echo "Creating pve-community.list"
	echo "deb http://download.proxmox.com/debian/pve $DISTRO pve-no-subscription" > /etc/apt/sources.list.d/pve-community.list
fi

if [ -e "/etc/apt/sources.list.d/ceph-community.disabled" ]; then
	echo "Enabling ceph-community.list"
	mv /etc/apt/sources.list.d/ceph-community.disabled /etc/apt/sources.list.d/ceph-community.list
else
	echo "Creating ceph-community.list"
	echo "deb http://download.proxmox.com/debian/ceph-quincy $DISTRO no-subscription" > /etc/apt/sources.list.d/ceph-community.list
fi

# Update repos
apt update
if [ $? -ne 0 ]; then
	echo "Failed to update apt repositories" >&2
	exit 1
fi