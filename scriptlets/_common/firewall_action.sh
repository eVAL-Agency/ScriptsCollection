# scriptlet:_common/get_firewall.sh
# scriptlet:_common/cmd_exists.sh
# scriptlet:bz_eval_log/log.sh
# scriptlet:firewalld/firewall_action_firewalld.sh
# scriptlet:iptables/firewall_action_iptables.sh
# scriptlet:proxmox/firewall_action_proxmox.sh
# scriptlet:ufw/firewall_action_ufw.sh

##
# Add a rule to the firewall in the INPUT chain
# This action can be "ALLOW" (default), DROP, or REJECT.
#
# General Arguments:
#   --action <allow|drop|reject> Action to perform (default: allow)
#   --comment <comment>          Comment for the rule
#
# Source Arguments:
#   --port <port>                Port(s) to allow/block
#   --source <source>            Source IP to allow/block
#   --ipset <name_of_rule>       Name of ipset to allow/block
#
# Port-Sourced Arguments (only apply when --port is used)
#   --protocol <tcp|udp>         Port protocol to allow/block (default: tcp)
#
# Aliases and Shorthand:
#   --allow                      Alias of --action allow
#   --drop                       Alias of --action drop
#   --from <source>              Alias of --source <source>
#   --proto <tcp|udp>            Alias of --protocol (tcp/udp)
#   --reject                     Alias of --action reject
#   --tcp                        Alias of --protocol tcp
#   --udp                        Alias of --protocol udp
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
# Allow a specific IP to access SSH
#   firewall_action --action allow --source 5.6.5.6 --port 22 --protocol tcp
#
# CHANGELOG:
#   2026.09.16 - Add support for ProxmoxVE Firewall
#   2026.09.15 - Re-enable support for SOURCE+PORT actions
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
	local PROTO=""
	local SOURCE=""

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
        	--allow) ACTION="ALLOW";;
			--comment)
				shift
				COMMENT=$1
				;;
     		--drop) ACTION="DROP";;
			--ipset)
				shift
				IPSET="$1"
				;;
			--port)
				shift
				PORT=$1
				;;
			--proto | --protocol)
				shift
				PROTO=$(echo "$1" | tr '[:upper:]' '[:lower:]')
				;;
			--tcp) PROTO="tcp" ;;
            --udp) PROTO="udp" ;;
   			--reject) ACTION="REJECT";;
			--source | --from)
				shift
				SOURCE=$1
				;;
			*)
				log_error "firewall_action: Unknown parameter requested [$1]"
				return 2
				;;
		esac
		shift
	done

	# Validate some arguments
	if [ -n "$IPSET" ] && [ -n "$SOURCE" ]; then
		log_error "firewall_action: --source and --ipset are mutually exclusive"
		return 2
	fi

	if [ -n "$IPSET" ] && [ -n "$PORT" ]; then
		log_error "firewall_action: --port and --ipset are mutually exclusive"
		return 2
	fi

	if [ -n "$IPSET" ] && [ -n "$PROTO" ]; then
		log_warning "firewall_action: --protocol has no function when --ipset is used"
	fi

	if [ -z "$PORT" ] && [ -n "$PROTO" ]; then
		log_warning "firewall_action: --protocol has no function without --port"
	fi

	if [ -n "$PORT" ] && [ -z "$PROTO" ]; then
		log_debug "firewall_action: --protocol was not set with --port, defaulting to --protocol tcp"
		PROTO="tcp"
	fi

	case "$ACTION" in
		"ALLOW" | "ACCEPT") ACTION="ALLOW" ;;
		"DROP" | "IGNORE") ACTION="DROP" ;;
		"REJECT" | "BLOCK") ACTION="REJECT" ;;
		*)
			log_error "firewall_action: Invalid --action requested, must be one of ALLOW | DROP | REJECT"
			return 2
			;;
	esac


	if [ -n "$IPSET" ]; then
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
		firewall_action_ufw "$ACTION" "$SOURCE" "$PORT" "$PROTO" "$IPSET" "$COMMENT"
	elif [ "$FIREWALL" == "firewalld" ]; then
		firewall_action_firewalld "$ACTION" "$SOURCE" "$PORT" "$PROTO" "$IPSET" "$COMMENT"
	elif [ "$FIREWALL" == "proxmox" ]; then
		firewall_action_proxmox "$ACTION" "$SOURCE" "$PORT" "$PROTO" "$IPSET" "$COMMENT"
	elif [ "$FIREWALL" == "iptables" ]; then
		firewall_action_iptables "$ACTION" "$SOURCE" "$PORT" "$PROTO" "$IPSET" "$COMMENT"
	else
		log_error "firewall_action: Unsupported or unknown firewall"
		log_error 'Please report this at https://github.com/eVAL-Agency/ScriptsCollection/issues'
		return 1
	fi
}
