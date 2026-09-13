# scriptlet:_common/get_firewall.sh
# scriptlet:_common/cmd_exists.sh
# scriptlet:bz_eval_log/log.sh

##
# Add a rule to the firewall in the INPUT chain
# This action can be "ALLOW" (default), DROP, or REJECT.
#
# General Arguments:
#   --action <allow|drop|reject> Action to perform (default: allow)
#   --comment <comment>          (only UFW) Comment for the rule
#
# Source Arguments (only 1 allowed):
#   --port <port>                Port(s) to allow/block
#   --source <source>            Source IP to allow/block
#   --ipset <name_of_rule>       Name of ipset to allow/block
#
# Port-Sourced Arguments (only apply when --port is used)
#   --protocol <tcp|udp>         Port protocol to allow/block (default: tcp)
#   --tcp                        Alias of --protocol tcp
#   --udp                        Alias of --protocol udp
#   --proto <tcp|udp>            Alias of --protocol (tcp/udp)
#
# Specify multiple ports with `--port '#,#,#'` or a range `--port '#:#'`
#
# EXAMPLES:
#
# Allow port 80 from all
#   firewall_action --port 80
#
# Allow DNS lookups from all
#   firewall_action --port 53 --udp
#
# Whitelist an IP address
#   firewall_action --source 1.2.3.4
#
# Block access from a specific IP
#   firewall_action --source 8.7.6.5 --action drop
#
# Block access from a list of ips
#   firewall_action --ipset blocklist --action drop
#
# CHANGELOG:
#   2026.09.13 - Switch to using log_* functions
#   2026.09.10 - Modify function to accept action rules for drop/reject support
#   2025.11.23 - Use return codes instead of exit to allow the caller to handle errors
#   2025.04.10 - Add "--proto" argument as alternative to "--tcp|--udp"
#
function firewall_action() {
	# Defaults
	local ACTION="ALLOW"
	local COMMENT=""
	local FIREWALL=$(get_available_firewall)
	local IPSET=""
	local PORT=""
	local PROTO="tcp"
	local SOURCE="any"

	# Internal variables
	local ZONE=""
	local ACTION_MSG=""
	local ACTION_IPTABLE=""
	local ACTION_UFW=""
	local TARGET_COUNT=0 # Should only be 1

	if [ "$FIREWALL" == "none" ]; then
		log_error "firewall_action: No firewall installed"
		return 1
	fi

	# Argument processing
	while [ $# -ge 1 ]; do
		case $1 in
			--action)
				shift
				ACTION=$(echo "$1" | tr '[:lower:]' '[:upper:]')
				;;
			--comment)
				shift
				COMMENT=$1
				;;
			--ipset)
				shift
				IPSET="$1"
				((TARGET_COUNT++))
				;;
			--port)
				shift
				PORT=$1
				((TARGET_COUNT++))
				;;
			--proto | --protocol)
				shift
				PROTO=$1
				;;
			--tcp | --udp)
				PROTO=${1:2}
				;;
			--source | --from)
				shift
				SOURCE=$1
				((TARGET_COUNT++))
				;;
			*)
				log_error "firewall_action: Unknown parameter requested [$1]"
				return 2
				;;
		esac
		shift
	done

	if [ $TARGET_COUNT -eq 0 ]; then
		# No port/source/ipset requested,
		# this would default to allow/block from ALL sources
		# and thus is rejected as an invalid request.
		log_error "firewall_action: No --port/--source/--ipset specified"
		return 2
	elif [ $TARGET_COUNT -gt 1 ]; then
		# More than one port/source/ipset requested,
		# while technically allowed, this script enforces a more simple structure
		log_error "firewall_action: Only one --port/--source/--ipset is allowed (mutually exclusive)"
		return 2
	fi

	case "$ACTION" in
		"ALLOW" | "ACCEPT")
			ACTION="ALLOW"
			ACTION_MSG="Allowing"
			ACTION_IPTABLE="ACCEPT"
			ACTION_UFW="allow"
		 	;;
		"DROP" | "IGNORE")
			ACTION="DROP"
		 	ACTION_MSG="Denying"
		 	ACTION_IPTABLE="DROP"
		 	ACTION_UFW="drop"
		 	;;
		"REJECT" | "BLOCK")
			ACTION="REJECT"
			ACTION_MSG="Rejecting"
			ACTION_IPTABLE="REJECT"
			ACTION_UFW="drop"
			;;
		*)
			log_error "firewall_action: Invalid --action requested, must be one of ALLOW | DROP | REJECT"
			return 2
			;;
	esac


	if [ "$IPSET" != "" ]; then
		# Pre-exec checks for ipset mode

		if ! cmd_exists "ipset"; then
			log_error "firewall_action: ipset not installed"
			return 2
		fi

		if ! ipset list "$IPSET" >/dev/null 2>&1; then
			log_error "firewall_action: ipset [$IPSET] does not exist yet"
			return 2
		fi
	fi


	if [ "$FIREWALL" == "ufw" ]; then
		# Actions specific for UFW

		if [ "$IPSET" != "" ]; then
			# ipset add rule, requires modification of configuration files
			log_info "firewall_action/UFW: $ACTION_MSG all connections from ipset $IPSET..."
			[ -e /etc/ufw/before.rules ] || touch /etc/ufw/before.rules
			if ! grep -q "match-set $IPSET src" /etc/ufw/before.rules; then
				sed -i "/COMMIT$/i\-A ufw-before-input -m set --match-set $IPSET src -j $ACTION_IPTABLE" /etc/ufw/before.rules
				systemctl restart ufw
			fi
		elif [ "$SOURCE" != "any" ]; then
			# Source-based rule
			log_info "firewall_action/UFW: $ACTION_MSG all connections from $SOURCE..."
			ufw $ACTION_UFW from $SOURCE comment "$COMMENT"
		else
			# Port/protocol-based rule
			log_info "firewall_action/UFW: $ACTION_MSG $PORT/$PROTO from any..."
			ufw $ACTION_UFW proto $PROTO to any port $PORT comment "$COMMENT"
		fi
		return 0
	elif [ "$FIREWALL" == "firewalld" ]; then
		# Actions specific for firewalld

		# firewalld is a zone-based firewall, so translate the zone based on the requested parameters
		local ZONE=""
		if [ "$ACTION" == "DROP" ] || [ "$ACTION" == "REJECT" ]; then
			ZONE="drop"
		elif [ "$ACTION" == "ALLOW" ] && [ "$SOURCE" != "any" ]; then
			ZONE="trusted"
		elif [ "$ACTION" == "ALLOW" ] && [ "$IPSET" != "" ]; then
			ZONE="trusted"
		else
			ZONE="public"
		fi

		if [ "$IPSET" != "" ]; then
			# ipset-based rule
			log_info "firewall_action/firewalld: Adding ipset $IPSET to $ZONE zone..."
			firewall-cmd --zone=$ZONE --add-source=ipset:$IPSET --permanent
		elif [ "$SOURCE" != "any" ]; then
			# Source-based rule
			log_info "firewall_action/firewalld: Adding $SOURCE to $ZONE zone..."
			firewall-cmd --zone=$ZONE --add-source=$SOURCE --permanent
		else
			# Port-based rule
			log_info "firewall_action/firewalld: Adding $PORT/$PROTO to $ZONE zone..."
			if [[ "$PORT" =~ ":" ]]; then
				# firewalld expects port ranges to be in the format of "#-#" vs "#:#"
				local DPORTS="${PORT/:/-}"
				firewall-cmd --zone=$ZONE --add-port=$DPORTS/$PROTO --permanent
			elif [[ "$PORT" =~ "," ]]; then
				# Firewalld cannot handle multiple ports all that well, so split them by the comma
				# and run the add command separately for each port
				local DPORTS="$(echo $PORT | sed 's:,: :g')"
				for P in $DPORTS; do
					firewall-cmd --zone=$ZONE --add-port=$P/$PROTO --permanent
				done
			else
				firewall-cmd --zone=$ZONE --add-port=$PORT/$PROTO --permanent
			fi
		fi

		# Firewalld must be reloaded for any rule change
		firewall-cmd --reload
		return 0
	elif [ "$FIREWALL" == "iptables" ]; then
		# Actions specific for iptables
		local CHAIN=""
		if [ "$ACTION" == "ALLOW" ]; then
			CHAIN="-A INPUT"
		else
			CHAIN="-I INPUT"
		fi

		if [ "$IPSET" != "" ]; then
			# ipset-based rule
			log_info "firewall_action/iptables: $ACTION_MSG all connections from ipset $IPSET..."
			iptables $CHAIN -m set --match-set $IPSET src -j $ACTION_IPTABLE
		elif [ "$SOURCE" != "any" ]; then
			# Source-based rule
			log_info "firewall_action/iptables: $ACTION_MSG all connections from $SOURCE..."
			iptables $CHAIN -s $SOURCE -j $ACTION_IPTABLE
		else
			# Port/protocol-based rule
			log_info "firewall_action/iptables: $ACTION_MSG $PORT/$PROTO from any..."
			# iptables doesn't natively support multiple ports, so we have to get creative
			if [[ "$PORT" =~ ":" ]]; then
				local DPORTS="-m multiport --dports $PORT"
			elif [[ "$PORT" =~ "," ]]; then
				local DPORTS="-m multiport --dports $PORT"
			else
				local DPORTS="--dport $PORT"
			fi
			iptables $CHAIN -p $PROTO $DPORTS -j $ACTION_IPTABLE
		fi

		iptables-save > /etc/iptables/rules.v4
		return 0
	else
		log_error "firewall_action: Unsupported or unknown firewall"
		log_error 'Please report this at https://github.com/eVAL-Agency/ScriptsCollection/issues'
		return 1
	fi
}
