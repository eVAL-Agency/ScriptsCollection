# scriptlet:bz_eval_log/log.sh

##
# Add rules to the Firewalld firewall
#
# CHANGELOG:
#   2026.09.16 - Initial port from _common/firewall_action.sh
#
function firewall_action_firewalld() {
	# Actions specific for firewalld
	local ACTION=$1
	local SOURCE=$2
	local PORT=$3
	local PROTO=$4
	local IPSET=$5
	local COMMENT=$6

	local ZONE=""
	local DPORTS=""

	# firewalld is a zone-based firewall, so translate the zone based on the requested parameters
	if [ "$ACTION" == "DROP" ] || [ "$ACTION" == "REJECT" ]; then
		ZONE="drop"
	elif [ "$ACTION" == "ALLOW" ] && [ -n "$SOURCE" ]; then
		ZONE="trusted"
	elif [ "$ACTION" == "ALLOW" ] && [ -n "$IPSET" ]; then
		ZONE="trusted"
	else
		ZONE="public"
	fi

	if [ -n "$PORT" ]; then
		# Firewalld cannot handle multiple ports all that well, so split them by the comma
		# and run the add command separately for each port
		IFS=',' read -ra DPORTS <<< "$PORT"
	fi

	if [ -n "$IPSET" ]; then
		# ipset-based rule
		log_info "firewall_action/firewalld: Adding ipset $IPSET to $ZONE zone..."
		firewall-cmd --zone="$ZONE" --add-source="ipset:$IPSET" --permanent
	elif [ -n "$SOURCE" ] && [ -n "$PORT" ]; then
		# Source + Port rule
		log_info "firewall_action/firewalld: Adding $PORT/$PROTO from $SOURCE to $ZONE zone..."
		for P in "${DPORTS[@]}"; do
			if [[ "$P" =~ ":" ]]; then
				# firewalld expects port ranges to be in the format of "#-#" vs "#:#"
				P="${P/:/-}"
			fi
			firewall-cmd --zone="$ZONE" --add-port="$P/$PROTO" --source="$SOURCE" --permanent
		done
	elif [ -n "$SOURCE" ]; then
		# Source-based rule
		log_info "firewall_action/firewalld: Adding $SOURCE to $ZONE zone..."
		firewall-cmd --zone="$ZONE" --add-source="$SOURCE" --permanent
	elif [ -n "$PORT" ]; then
		# Port-based rule
		log_info "firewall_action/firewalld: Adding $PORT/$PROTO to $ZONE zone..."
		for P in "${DPORTS[@]}"; do
			if [[ "$P" =~ ":" ]]; then
				# firewalld expects port ranges to be in the format of "#-#" vs "#:#"
				P="${P/:/-}"
			fi
			firewall-cmd --zone="$ZONE" --add-port="$P/$PROTO" --permanent
		done
	else
		log_error "firewall_action/firewalld: Invalid rule requested"
		return 2
	fi

	# Firewalld must be reloaded for any rule change
	firewall-cmd --reload
	return 0
}
