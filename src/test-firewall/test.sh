#!/bin/bash

# scriptlet:_common/get_firewall.sh
# scriptlet:ufw/install.sh
# scriptlet:firewalld/install.sh
# scriptlet:_common/firewall_allow.sh
# scriptlet:_common/package_remove.sh
# scriptlet:_common/package_install.sh

echo "Firewall: $(get_available_firewall)"

if [ "$(get_available_firewall)" == "ufw" ]; then
	package_remove ufw
fi
if [ "$(get_available_firewall)" == "firewalld" ]; then
	package_remove firewalld
fi
if [ "$(get_available_firewall)" == "iptables" ]; then
	package_remove iptables
fi

if [ "$1" == "ufw" ]; then
	install_ufw
elif [ "$1" == "firewalld" ]; then
	install_firewalld
elif [ "$1" == "iptables" ]; then
	package_install iptables
else
	echo "Unknown firewall: $1" >&2
	exit 1
fi

echo "Firewall: $(get_available_firewall)"

firewall_allow --port "16261:16262" --udp
firewall_allow --port "1234" --tcp
firewall_allow --port "111,2049" --tcp --zone internal --source 1.2.3.4/32
firewall_allow --zone trusted --source 6.7.8.9/32

# Status print (debugging)
FIREWALL="$(get_available_firewall)"
if [ "$FIREWALL" == "ufw" ]; then
	ufw status verbose
elif [ "$FIREWALL" == "firewalld" ]; then
	firewall-cmd --list-all --zone=public
	firewall-cmd --list-all --zone=internal
	firewall-cmd --list-all --zone=trusted
elif [ "$FIREWALL" == "iptables" ]; then
	iptables -L -v
fi