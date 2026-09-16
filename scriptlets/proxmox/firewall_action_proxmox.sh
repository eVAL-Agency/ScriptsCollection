# scriptlet:bz_eval_log/log.sh

##
# Add rules to the Proxmox firewall
#
# CHANGELOG:
#   2026.09.16 - Initial version
#
function firewall_action_proxmox() {
	# Arguments are positional from the Orchestrator
	local ACTION=$1
	local SOURCE=$2
	local PORT=$3
	local PROTO=$4
	local IPSET=$5
	local COMMENT=$6

	# Map Action to PVE/Iptables compatible strings
	[[ "$ACTION" == "ALLOW" ]] && ACTION="ACCEPT"

	# Node Detection
	local LOCAL_HOST=$(hostname -s)
	local NODE_NAME=""
	for node_dir in /etc/pve/nodes/*; do
		local current_node=$(basename "$node_dir")
		if [[ "$LOCAL_HOST" == "$current_node"* ]]; then
			NODE_NAME="$current_node"
			break
		fi
	done

	if [ -z "$NODE_NAME" ]; then
		log_error "firewall_action/proxmox: Could not identify node name";
		return 2
	fi

	local PVES_PATH="/nodes/$NODE_NAME/firewall/rules"

	# Execution Logic
	if [ -n "$IPSET" ]; then
		# --- IPSET BYPASS MODE (High Performance) ---
		log_info "firewall_action/proxmox: Using iptables bypass for IPSET on $NODE_NAME..."
		local CHAIN=""
		if [ "$ACTION" == "ACCEPT" ]; then
			# Allow actions get **A**ppended to the end of the list
			CHAIN="-A INPUT"
		else
			# Drop/Reject actions get **I**nserted at the beginning of the list
			CHAIN="-I INPUT"
		fi

		local DPORTS=""
		if [ -n "$PORT" ]; then
			# iptables doesn't natively support multiple ports, so we have to get creative
			if [[ "$PORT" =~ ":" ]]; then
				DPORTS="-m multiport --dports $PORT"
			elif [[ "$PORT" =~ "," ]]; then
				DPORTS="-m multiport --dports $PORT"
			else
				DPORTS="--dport $PORT"
			fi
		fi

		iptables $CHAIN -m set --match-set "$IPSET" src -p $PROTO $DPORTS -j $ACTION
	else
		# --- STANDARD PVE API MODE (GUI Integration) ---
		local PVES_ARGS=("create" "$PVES_PATH" "--action" "$ACTION" "--type" "in")
		local MSG=("firewall_action/proxmox: Adding rule to PVE -" "$ACTION")
		if [ -n "$SOURCE" ]; then
			PVES_ARGS+=("--source" "$SOURCE")
			MSG+=("from" "$SOURCE")
		fi

		if [ -n "$PORT" ]; then
			PVES_ARGS+=("--dport" "$PORT")
			MSG+=("to" "$PORT")
			if [ -n "$PROTO" ]; then
				PVES_ARGS+=("--proto" "$PROTO")
				MSG+=("/$PROTO")
			fi
		fi

		if [ -n "$COMMENT" ]; then
			PVES_ARGS+=("--comment" "$COMMENT")
		fi

		PVES_ARGS+=("--enable" 1)

		log_info "${MSG[*]}..."
		pvesh "${PVES_ARGS[@]}" || return 2
	fi

	return 0
}
