#!/bin/bash

# scriptlet:_common/get_firewall.sh
# scriptlet:ufw/install.sh
# scriptlet:_common/firewall_allow.sh

echo "Firewall: $(get_enabled_firewall)"
if [ "$(get_enabled_firewall)" == "none" ]; then
	install_ufw
fi

firewall_allow --port "16261:16262" --udp
firewall_allow --port "1234" --tcp
firewall_allow --port "111,2049" --tcp --zone internal --source 1.2.3.4/32