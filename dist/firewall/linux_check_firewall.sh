#!/bin/bash
#
# Linux Firewall - Check Status
#
# Check the status of the firewall on a Linux system and print any rules defined.
#
# Supports:
#   Linux-All
#
# Category:
#   Security

##
# Get which firewall is enabled,
# or "none" if none located
function get_enabled_firewall() {
	if [ "$(systemctl is-active firewalld)" == "active" ]; then
		echo "firewalld"
	elif [ "$(systemctl is-active ufw)" == "active" ]; then
		echo "ufw"
	elif [ "$(systemctl is-active iptables)" == "active" ]; then
		echo "iptables"
	else
		echo "none"
	fi
}

##
# Get which firewall is available on the local system,
# or "none" if none located
function get_available_firewall() {
	if systemctl list-unit-files firewalld.service &>/dev/null; then
		echo "firewalld"
	elif systemctl list-unit-files ufw.service &>/dev/null; then
		echo "ufw"
	elif systemctl list-unit-files iptables.service &>/dev/null; then
		echo "iptables"
	else
		echo "none"
	fi
}

FIREWALL_AVAILABLE="$(get_available_firewall)"
FIREWALL_ENABLED="$(get_enabled_firewall)"

if [ "$FIREWALL_AVAILABLE" == "none" ]; then
	echo "No firewall installed"
	exit 1
fi

if [ "$FIREWALL_ENABLED" == "none" ]; then
	echo "Firewall: $FIREWALL_AVAILABLE - Status: Disabled"
	exit 1
elif [ "$FIREWALL_ENABLED" != "$FIREWALL_AVAILABLE" ]; then
	echo "WARNING - Firewall $FIREWALL_AVAILABLE installed but $FIREWALL_ENABLED is enabled"
	exit 1
else
	echo "Firewall: $FIREWALL_AVAILABLE - Status: Enabled"
fi


if [ "$FIREWALL_ENABLED" == "ufw" ]; then
	ufw status verbose
elif [ "$FIREWALL_ENABLED" == "firewalld" ]; then
	for ZONE in $(firewall-cmd --get-zones); do
		firewall-cmd --list-all --zone=$ZONE
	done
#elif [ "$FIREWALL_ENABLED" == "iptables" ]; then
#	iptables -L -v
fi