#!/bin/bash
#
# Block Bad IPs [Linux]
#
# Add firewall rules to block known bad-IPs on the system firewall
#
# Tor data provided by the Tor Onionoo service:
# https://metrics.torproject.org/onionoo.html
#
# Spamhaus DROP list (Dont-Route-Or-Peer):
# https://www.spamhaus.org/blocklists/do-not-route-or-peer/
#
# Active threat data provided by CI Army:
# https://www.ciarmy.com/
#
# Supports:
#   Linux-All
#
# Category:
#   Firewall
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
#   2026.09.12 - Initial version

# scriptlet:_common/firewall_install.sh
# scriptlet:_common/get_firewall.sh
# scriptlet:_common/firewall_action.sh
# scriptlet:_common/download.sh
# scriptlet:_common/package_install.sh
# scriptlet:ipset/ipset.sh
# scriptlet:bz_eval_log/log.sh
# scriptlet:_common/require_root.sh

# Some functions used herein
# Function to validate if a string is a valid IPv4 address
function validate_ip() {
	local ip=$1

	# Regex checks for 4 groups of 1-3 digits separated by dots, optionally followed by /prefix
	if [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})(/([0-9]{1,2}))?$ ]]; then
		# Check that each octet is between 0 and 255
		for i in 1 2 3 4; do
			if (( ${BASH_REMATCH[$i]} > 255 )); then
				return 1
			fi
		done

		# Check that the prefix (if present) is between 0 and 32
		if [[ -n "${BASH_REMATCH[6]}" ]]; then
			if (( ${BASH_REMATCH[6]} > 32 )); then
				return 1
			fi
		fi
		return 0
	fi
	return 1
}

# Ensure dependencies are installed
firewall_install
package_install_if jq

FIREWALL_AVAILABLE="$(get_available_firewall)"
if [ "$FIREWALL_AVAILABLE" == "none" ]; then
	log_error "Firewall auto-install failed"
	exit 1
fi

# Create and enable the ipsets for the various sources
ipset_create --name "tor_exits" --timeout 86400
firewall_action --ipset "tor_exits" --action drop

ipset_create --name "spamhaus_drop" --timeout 86400 --type "hash:net"
firewall_action --ipset "spamhaus_drop" --action drop

ipset_create --name "cins_threats" --timeout 86400
firewall_action --ipset "cins_threats" --action drop


# Download list of tor exit nodes
# Data provided by Tor Onionoo service
# https://metrics.torproject.org/onionoo.html
TOR_DATA="$(mktemp --suffix=.json)"
log_info "Downloading IP list for Tor exit nodes..."
if download "https://onionoo.torproject.org/details?search=type:relay%20running:true" "$TOR_DATA"; then
	# Download was successful; create the temp list for these updates
	log_info "Populating list for Tor exit nodes..."
	ipset_create --name "tor_exits_temp" --temp --timeout 86400

	added_count=0
	failed_count=0

	# Search through the JSON data for any currently-running service
	# that is marked as an Exit node (.flags[] contains "Exit")
	# and return the list of exit addresses (.exit_addresses[])
	while read -r IP; do
		if [[ -n "$IP" ]]; then
			if validate_ip "$IP"; then
				# Add this to the blocklist
				if ipset -exist add "tor_exits_temp" "$IP"; then
					((added_count++))
				else
					((failed_count++))
				fi
			else
				((failed_count++))
			fi
		fi
	done < <(jq -r '.relays[] | select(.flags // [] | any(. == "Exit")) | .exit_addresses[]?' "$TOR_DATA" 2>/dev/null)

	log_info "Tor exit node update complete: $added_count added, $failed_count failed validation."

	# Merge the updated list back to the live copy
	ipset_swap "tor_exits" "tor_exits_temp"

	# Cleanup
	[ -n "$TOR_DATA" ] && [ -f "$TOR_DATA" ] && rm "$TOR_DATA"
fi


# Download list of DROP sources
# Data provided by Spamhaus Project
# https://www.spamhaus.org/blocklists/do-not-route-or-peer/
DROP_DATA="$(mktemp --suffix=.json)"
log_info "Downloading IP list for DROP data..."
if download "https://www.spamhaus.org/drop/drop_v4.json" "$DROP_DATA"; then
	# Download was successful; create the temp list for these updates
	log_info "Populating list for DROP data..."
	ipset_create --name "spamhaus_drop_temp" --temp --timeout 86400 --type "hash:net"

	added_count=0
	failed_count=0

	# Search through the JSON data for any currently-running service
	# that is marked as an Exit node (.flags[] contains "Exit")
	# and return the list of exit addresses (.exit_addresses[])
	while read -r IP; do
		if [[ -n "$IP" ]]; then
			if validate_ip "$IP"; then
				# Add this to the blocklist
				if ipset -exist add "spamhaus_drop_temp" "$IP"; then
					((added_count++))
				else
					((failed_count++))
				fi
			else
				((failed_count++))
			fi
		fi
	done < <(jq -r 'select(has("cidr")) | .cidr' "$DROP_DATA" 2>/dev/null)

	log_info "Spamhaus DROP update complete: $added_count added, $failed_count failed validation."

	# Merge the updated list back to the live copy
	ipset_swap "spamhaus_drop" "spamhaus_drop_temp"

	# Cleanup
	[ -n "$DROP_DATA" ] && [ -f "$DROP_DATA" ] && rm "$DROP_DATA"
fi


# Download list of active threat actors
# Data provided by CI Army (CINS)
# https://www.ciarmy.com/
CINS_DATA="$(mktemp --suffix=.txt)"
log_info "Downloading IP list for CINS threat data..."
if download "http://cinsscore.com/list/ci-badguys.txt" "$CINS_DATA"; then
	log_info "Populating list for CINS threat data..."
	# Download was successful; create the temp list for these updates
	ipset_create --name "cins_threats_temp" --temp --timeout 86400

	added_count=0
	failed_count=0

	# This feed is just raw plain text, iterate through each line
	while read -r IP; do
		if [[ -n "$IP" ]]; then
			if validate_ip "$IP"; then
				# Add this to the blocklist
				if ipset -exist add "cins_threats_temp" "$IP"; then
					((added_count++))
				else
					((failed_count++))
				fi
			else
				((failed_count++))
			fi
		fi
	done < "$CINS_DATA"

	log_info "CINS Active Threat update complete: $added_count added, $failed_count failed validation."

	# Merge the updated list back to the live copy
	ipset_swap "cins_threats" "cins_threats_temp"

	# Cleanup
	[ -n "$CINS_DATA" ] && [ -f "$CINS_DATA" ] && rm "$CINS_DATA"
fi
