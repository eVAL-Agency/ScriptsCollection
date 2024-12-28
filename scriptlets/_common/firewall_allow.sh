# scriptlet:_common/get_firewall.sh
##
# Add an "allow" rule to the firewall in the INPUT chain
#
# Arguments:
#   --port <port>      Port(s) to allow
#   --source <source>  Source IP to allow (default: any)
#   --zone <zone>      (only with firewalld) Zone to allow (default: public)
#   --tcp|--udp        Protocol to allow (default: tcp)
#
# Specify multiple ports with `--port '#,#,#'` or a range `--port '#:#'`
function firewall_allow() {
	# Defaults and argument processing
	local PORT=""
	local PROTO="tcp"
	local SOURCE="any"
	local FIREWALL=$(get_enabled_firewall)
	local ZONE="public"
	while [ $# -ge 1 ]; do
		case $1 in
			--port)
				shift
				PORT=$1
				;;
			--tcp|--udp)
				PROTO=${1:2}
				;;
			--source|--from)
				shift
				SOURCE=$1
				;;
			--zone)
				shift
				ZONE=$1
				;;
			*)
				PORT=$1
				;;
		esac
		shift
	done

	if [ "$PORT" == "" ]; then
		echo "firewall_allow: No port specified!" >&2
		exit 1
	fi

	if [ "$FIREWALL" == "ufw" ]; then
		if [ "$SOURCE" == "any" ]; then
			echo "firewall_allow/UFW: Allowing $PORT/$PROTO from any..."
			ufw allow proto $PROTO $PORT
		else
			echo "firewall_allow/UFW: Allowing $PORT/$PROTO from $SOURCE..."
			ufw allow from $SOURCE proto $PROTO to any port $PORT
		fi
	elif [ "$FIREWALL" == "firewalld" ]; then
		if [ "$SOURCE" == "any" ]; then
			echo "firewall_allow/firewalld: Allowing $PORT/$PROTO from any in zone $ZONE..."
			firewall-cmd --zone=$ZONE --add-port=$PORT/$PROTO --permanent
		else
			echo "firewall_allow/firewalld: Allowing $PORT/$PROTO from $SOURCE in zone $ZONE..."
			firewall-cmd --zone=$ZONE --add-source=$SOURCE --permanent
			firewall-cmd --zone=$ZONE --add-port=$PORT/$PROTO --permanent
		fi
		firewall-cmd --reload
	elif [ "$FIREWALL" == "iptables" ]; then
		# iptables doesn't natively support multiple ports, so we have to get creative
		if [[ "$PORT" =~ ":" ]]; then
			local DPORTS="-m multiport --dports $PORT"
		elif [[ "$PORT" =~ "," ]]; then
			local DPORTS="-m multiport --dports $PORT"
		else
			local DPORTS="--dport $PORT"
		fi

		if [ "$SOURCE" == "any" ]; then
			echo "firewall_allow/iptables: Allowing $PORT/$PROTO from any..."
			iptables -A INPUT -p $PROTO $DPORTS -j ACCEPT
		else
			echo "firewall_allow/iptables: Allowing $PORT/$PROTO from $SOURCE..."
			iptables -A INPUT -p $PROTO $DPORTS -s $SOURCE -j ACCEPT
		fi
		iptables-save > /etc/iptables/rules.v4
	elif [ "$FIREWALL" == "none" ]; then
		echo "firewall_allow: No firewall detected" >&2
		exit 1
	else
		echo "firewall_allow: Unsupported or unknown firewall" >&2
		echo 'Please report this at https://github.com/cdp1337/ScriptsCollection/issues' >&2
		exit 1
	fi
}
