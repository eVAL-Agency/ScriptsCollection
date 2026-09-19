# scriptlet:bz_eval_log/log.sh

##
# Add rules to the iptables firewall
#
# CHANGELOG:
#   2026.09.16 - Initial port from _common/firewall_action.sh
#
function firewall_action_iptables() {
	# Actions specific for iptables
	local ACTION=$1
	local SOURCE=$2
	local PORT=$3
	local PROTO=$4
	local IPSET=$5
	local COMMENT=$6
	local CHAIN=""
	local DPORTS=""

	# Map Action to Iptables compatible strings
	[[ "$ACTION" == "ALLOW" ]] && ACTION="ACCEPT"

	local CMD_ARGS=()
	local MSG=("firewall_action/iptables: Adding rule -" "$ACTION")

	if [ "$ACTION" == "ACCEPT" ]; then
		# Allow actions get **A**ppended to the end of the list
		CMD_ARGS+=("-A" "INPUT")
	else
		# Drop/Reject actions get **I**nserted at the beginning of the list
		CMD_ARGS+=("-I" "INPUT")
	fi

	if [ -n "$IPSET" ]; then
		CMD_ARGS+=("-m" "set" "--match-set" "$IPSET" "src")
		MSG+=("from ipset" "$IPSET")
	fi

	if [ -n "$SOURCE" ]; then
		CMD_ARGS+=("-s" "$SOURCE")
		MSG+=("from" "$SOURCE")
	fi

	if [ -n "$PORT" ]; then
		# iptables doesn't natively support multiple ports, so we have to get creative
		MSG+=("to" "$PORT/$PROTO")
		if [[ "$PORT" =~ ":" ]] || [[ "$PORT" =~ "," ]]; then
			CMD_ARGS+=("-p" "$PROTO" "-m" "multiport" "--dports" "$PORT")
		else
			CMD_ARGS+=("-p" "$PROTO" "--dport" "$PORT")
		fi
	fi

	CMD_ARGS+=("-j" "$ACTION")

	log_info "${MSG[*]}..."
	iptables "${CMD_ARGS[@]}" || return 2
	iptables-save > /etc/iptables/rules.v4
	return 0
}