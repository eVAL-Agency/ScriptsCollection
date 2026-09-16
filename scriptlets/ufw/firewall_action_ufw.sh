# scriptlet:bz_eval_log/log.sh

##
# Add rules to the UFW firewall
#
# CHANGELOG:
#   2026.09.16 - Initial port from _common/firewall_action.sh
#
function firewall_action_ufw() {
	# Actions specific for UFW

	local ACTION=$1
	local SOURCE=$2
	local PORT=$3
	local PROTO=$4
	local IPSET=$5
	local COMMENT=$6

	# Map Action to UFW and Iptables compatible strings
	local ACTION_IPTABLE=""
	[[ "$ACTION" == "ALLOW" ]] && ACTION_IPTABLE="ACCEPT" && ACTION="allow"
	[[ "$ACTION" == "DROP" ]] && ACTION_IPTABLE="DROP" && ACTION="drop"
	[[ "$ACTION" == "REJECT" ]] && ACTION_IPTABLE="REJECT" && ACTION="drop"

	if [ -n "$IPSET" ]; then
		# ipset add rule, requires modification of configuration files
		log_info "firewall_action/UFW: Setting all connections from ipset $IPSET as $ACTION..."
		[ -e /etc/ufw/before.rules ] || touch /etc/ufw/before.rules
		if ! grep -q "match-set $IPSET src" /etc/ufw/before.rules; then
			sed -i "/COMMIT$/i\-A ufw-before-input -m set --match-set $IPSET src -j $ACTION_IPTABLE" /etc/ufw/before.rules
			ufw reload
		fi
	elif [ -n "$SOURCE" ] && [ -n "$PORT" ]; then
		# Source + Port rule
		log_info "firewall_action/UFW: Setting connections from $SOURCE to $PORT/$PROTO as $ACTION..."
		ufw $ACTION from $SOURCE proto $PROTO to any port $PORT comment "$COMMENT"
	elif [ -n "$SOURCE" ]; then
		# Source-based rule
		log_info "firewall_action/UFW: Setting connections from $SOURCE as $ACTION..."
		ufw $ACTION from $SOURCE comment "$COMMENT"
	elif [ -n "$PORT" ]; then
		# Port/protocol-based rule
		log_info "firewall_action/UFW: Setting all connections to $PORT/$PROTO as $ACTION..."
		ufw $ACTION proto $PROTO to any port $PORT comment "$COMMENT"
	else
		log_error "firewall_action/UFW: Invalid rule requested"
		return 2
	fi
	return 0
}
