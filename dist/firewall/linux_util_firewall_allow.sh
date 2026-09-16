#!/bin/bash
#
# Firewall - Allow IP/Port [Linux]
#
# Allow a service and/or source in the firewall.
#
# Examples:
#   Allow http/https - linux_util_firewall_allow.sh --port="80,443"
#   Allow DNS - linux_util_firewall_allow.sh --port=53 --proto=udp
#   Whitelist IP - linux_util_firewall_allow.sh --ip=5.4.5.4
#   Allow IP to access port - linux_util_firewall_allow.sh --ip=5.4.5.4 --port=22
#
# Supports:
#   Linux-All
#
# Category:
#   Security
#
# Syntax:
#   --ip=<string> - IP address or CIDR network to allow DEFAULT=""
#   --port=<string> - Port(s) to allow DEFAULT=""
#   --proto=<tcp|udp> - Protocol to allow DEFAULT=tcp
#   --comment=<comment> - Optional comment for the rule
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
#   2026.09.16 - Add support for ProxmoxVE Firewall
#   2026.09.15 - Retool to use firewall_action and auto-install the system firewall if necessary
#   2025.04.10 - Initial version

##
# Simple wrapper to emulate `which -s`
#
# The -s flag is not available on all systems, so this function
# provides a consistent way to check for command existence
# without having to include '&>/dev/null' everywhere.
#
# Returns 0 on success, 1 on failure
#
# Arguments:
#   $1 - Command to check
#
# CHANGELOG:
#   2025.12.15 - Initial version (for a regression fix)
#
function cmd_exists() {
	local CMD="$1"
	which "$CMD" &>/dev/null
	return $?
}

##
# Get which firewall is enabled or "none" if none currently active
#
# CHANGELOG:
#   2026.09.16 - Add support for ProxmoxVE Firewall
#
function get_enabled_firewall() {
	if [ "$(systemctl is-active firewalld)" == "active" ]; then
		echo "firewalld"
	elif [ "$(systemctl is-active ufw)" == "active" ]; then
		echo "ufw"
	elif cmd_exists pvesh && [ "$(pve-firewall status)" == "Status: enabled/running" ]; then
		echo "proxmox"
	elif [ "$(systemctl is-active iptables)" == "active" ]; then
		echo "iptables"
	else
		echo "none"
	fi
}

##
# Get which firewall is available on the local system or "none" if none located
#
# CHANGELOG:
#   2026.09.16 - Add support for ProxmoxVE Firewall
#   2025.12.15 - Use cmd_exists to fix regression bug
#   2025.04.10 - Switch from "systemctl list-unit-files" to "which" to support older systems
#
function get_available_firewall() {
	if cmd_exists firewall-cmd; then
		echo "firewalld"
	elif cmd_exists ufw; then
		echo "ufw"
	elif cmd_exists pvesh; then
	   echo "proxmox"
	elif cmd_exists iptables; then
		echo "iptables"
	else
		echo "none"
	fi
}
##
# log helper by eval.bz
#
# Facilitates a basic logging system for Bash to print messages to stderr
#
# Using:
#
# Include this file (or however your import system works)
# # scriptlet: bz_eval_log/log.sh
#
# Change logging level
# LOG_LEVEL=3 - Set logging level to DEBUG so all messages are displayed
# LOG_LEVEL=2 - (DEFAULT) - Set logging to info, warnings, and errors
# LOG_LEVEL=1 - Only display warnings and errors
# LOG_LEVEL=0 - Only display errors
#
# Disable coloration
# By default this script renders messages with colors.  Disable this with the following
# LOG_COLORS=0
#
# Logging messages
# log_debug "This is a debug statement"
# log_info "This is an informational statement"
# log_warning "This is a warning message"
# log_error "This is an error message"
#

# Set the verbosity level: 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG
LOG_LEVEL=${LOG_LEVEL:-2}

# Set to '0' to disable ANSI colors
LOG_COLORS=1

# ANSI Color Codes
LOG_RED='\033[0;31m'
LOG_GREEN='\033[0;32m'
LOG_YELLOW='\033[1;33m'
LOG_BLUE='\033[0;34m'
LOG_NC='\033[0m' # No Color

##
# Print a header message
#
# CHANGELOG:
#   2026.04.30 - Initial version
#
function bz_eval_log() {
    local level_name="$1"
    local color
    local message="$2"
    local numeric_level=0

    # Map level names to numbers for comparison
    case "${level_name^^}" in
        "ERROR") numeric_level=0; color="$LOG_RED" ;;
        "WARN")  numeric_level=1; color="$LOG_YELLOW" ;;
        "INFO")  numeric_level=2; color="" ;;
        "DEBUG") numeric_level=3; color="$LOG_BLUE" ;;
    esac

    # Only print if the current log level is high enough
    if [ "$numeric_level" -le "$LOG_LEVEL" ]; then
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        # Print to stderr (&2)
        if [ $LOG_COLORS -eq 1 ] && [ "$color" != "" ]; then
        	printf "${color}[%s] [%s] %s${LOG_NC}\n" "$timestamp" "$level_name" "$message" >&2
		else
        	printf "[%s] [%s] %s\n" "$timestamp" "$level_name" "$message" >&2
        fi
    fi
}

# Helper wrappers for convenience
function log_error()   { bz_eval_log "ERROR" "$1"; }
function log_warning() { bz_eval_log "WARN"  "$1"; }
function log_info()    { bz_eval_log "INFO"  "$1"; }
function log_debug()   { bz_eval_log "DEBUG" "$1"; }

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
			CMD_ARGS+=("-m" "multiport" "--dports" "$PORT" "-p" "$PROTO")
		else
			CMD_ARGS+=("--dport" "$PORT" "-p" "$PROTO")
		fi
	fi

	CMD_ARGS+=("-j" "ACTION")

	log_info "${MSG[*]}..."
	iptables "${CMD_ARGS[@]}" || return 2
	iptables-save > /etc/iptables/rules.v4
	return 0
}

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
##
# Check if the OS is "like" a certain type
#
# Returns 0 if true, 1 if false
#
# Usage:
#   if os_like debian; then ... ; fi
#
function os_like() {
	local OS="$1"

	if [ -f '/etc/os-release' ]; then
		ID="$(grep -E '^ID=' /etc/os-release | sed 's:ID=::')"
		LIKE="$(grep -E '^ID_LIKE=' /etc/os-release | sed 's:ID_LIKE=::')"

		if [[ "$LIKE" =~ "$OS" ]] || [ "$ID" == "$OS" ]; then
			return 0;
		fi
	fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_debian)" -eq 1 ]; then ... ; fi
#   if os_like_debian -q; then ... ; fi
#
function os_like_debian() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like debian || os_like ubuntu; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_ubuntu)" -eq 1 ]; then ... ; fi
#   if os_like_ubuntu -q; then ... ; fi
#
function os_like_ubuntu() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like ubuntu; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_rhel)" -eq 1 ]; then ... ; fi
#   if os_like_rhel -q; then ... ; fi
#
function os_like_rhel() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like rhel || os_like fedora || os_like rocky || os_like centos; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_suse)" -eq 1 ]; then ... ; fi
#   if os_like_suse -q; then ... ; fi
#
function os_like_suse() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like suse; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_arch)" -eq 1 ]; then ... ; fi
#   if os_like_arch -q; then ... ; fi
#
function os_like_arch() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if os_like arch; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	fi

	if [ $QUIET -eq 0 ]; then echo 0; fi
	return 1
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_bsd)" -eq 1 ]; then ... ; fi
#   if os_like_bsd -q; then ... ; fi
#
function os_like_bsd() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if [ "$(uname -s)" == 'FreeBSD' ]; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	else
		if [ $QUIET -eq 0 ]; then echo 0; fi
		return 1
	fi
}

##
# Check if the OS is "like" a certain type
#
# ie: "ubuntu" will be like "debian"
#
# Returns 0 if true, 1 if false
# Prints 1 if true, 0 if false
#
# Usage:
#   if [ "$(os_like_macos)" -eq 1 ]; then ... ; fi
#   if os_like_macos -q; then ... ; fi
#
function os_like_macos() {
	local QUIET=0
	while [ $# -ge 1 ]; do
		case $1 in
			-q)
				QUIET=1;;
		esac
		shift
	done

	if [ "$(uname -s)" == 'Darwin' ]; then
		if [ $QUIET -eq 0 ]; then echo 1; fi
		return 0;
	else
		if [ $QUIET -eq 0 ]; then echo 0; fi
		return 1
	fi
}
##
# Get the operating system version
#
# Just the major version number is returned
#
function os_version() {
	if [ "$(uname -s)" == 'FreeBSD' ]; then
		local _V="$(uname -K)"
		if [ ${#_V} -eq 6 ]; then
			echo "${_V:0:1}"
		elif [ ${#_V} -eq 7 ]; then
			echo "${_V:0:2}"
		fi

	elif [ -f '/etc/os-release' ]; then
		local VERS="$(grep -E '^VERSION_ID=' /etc/os-release | sed 's:VERSION_ID=::')"

		if [[ "$VERS" =~ '"' ]]; then
			# Strip quotes around the OS name
			VERS="$(echo "$VERS" | sed 's:"::g')"
		fi

		if [[ "$VERS" =~ \. ]]; then
			# Remove the decimal point and everything after
			# Trims "24.04" down to "24"
			VERS="${VERS/\.*/}"
		fi

		if [[ "$VERS" =~ "v" ]]; then
			# Remove the "v" from the version
			# Trims "v24" down to "24"
			VERS="${VERS/v/}"
		fi

		echo "$VERS"

	else
		echo 0
	fi
}

_PACKAGE_INSTALL_UPDATED=0

##
# Install a package with the system's package manager.
#
# Uses Redhat's yum, Debian's apt-get, and SuSE's zypper.
#
# Usage:
#
# ```syntax-shell
# package_install apache2 php7.0 mariadb-server
# ```
#
# @param $1..$N string
#        Package, (or packages), to install.  Accepts multiple packages at once.
#
#
# CHANGELOG:
#   2026.09.12 - Revert paru; it requires NOT root access, which is counter to these scripts
#              - Add update support to issue a repo update once per execution
#   2026.07.08 - Add paru support for Arch's AUR
#   2026.01.09 - Cleanup os_like a bit and add support for RHEL 9's dnf
#   2025.04.10 - Set Debian frontend to noninteractive
#
function package_install (){
	echo "package_install: Installing $*..."

	if [ $_PACKAGE_INSTALL_UPDATED -eq 0 ]; then
		# Perform a system update before requesting the install.
		# This is cached in the runtime so it's only executed once per run
		if os_like_bsd -q; then
			pkg update -y
		elif os_like_debian -q; then
			DEBIAN_FRONTEND="noninteractive" apt-get update -y
		elif os_like_rhel -q; then
			if [ "$(os_version)" -ge 9 ]; then
				dnf makecache
			else
				yum makecache
			fi
		elif os_like_arch -q; then
			pacman -Sy --noconfirm
		elif os_like_suse -q; then
			zypper refresh
		fi

		_PACKAGE_INSTALL_UPDATED=1
	fi

	if os_like_bsd -q; then
		pkg install -y $*
	elif os_like_debian -q; then
		DEBIAN_FRONTEND="noninteractive" apt-get -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" install -y $*
	elif os_like_rhel -q; then
		if [ "$(os_version)" -ge 9 ]; then
			dnf install -y $*
		else
			yum install -y $*
		fi
	elif os_like_arch -q; then
		pacman -S --noconfirm $*
	elif os_like_suse -q; then
		zypper install -y $*
	else
		echo 'package_install: Unsupported or unknown OS' >&2
		echo 'Please report this at https://github.com/eVAL-Agency/ScriptsCollection/issues' >&2
		exit 1
	fi
}

##
# Perform a package installation IF the requested binary is not located
#
# If one argument is requested, the argument is used for both binary check and install package.
# When two arguments are provided, the first is the binary to check and the second is the package name.
#
# Examples:
#
# Simple check
#   package_install_if jq
#
# Varying package name vs binary
#   package_install_if php php8.4
#
# CHANGELOG:
#   2026.09.12 - Initial version
#
function package_install_if() {
	local PKG_NAME=""
	local PKG_BIN=""
	if [ $# -ge 2 ]; then
		PKG_BIN="$1"
		PKG_NAME="$2"
	elif [ $# -eq 1 ]; then
		PKG_BIN="$1"
		PKG_NAME="$1"
	else
		echo "package_install_if: Requires at least one argument" >&2
		exit 1
	fi

	if ! cmd_exists "$PKG_BIN"; then
		package_install "$PKG_NAME"
	fi
}

##
# Install UFW
#
function install_ufw() {
	if [ "$(os_like_rhel)" == 1 ]; then
		# RHEL/CentOS requires EPEL to be installed first
		package_install epel-release
	fi

	package_install ufw

	# Auto-enable a newly installed firewall
	ufw --force enable
	systemctl enable ufw
	systemctl start ufw

	# Auto-add the current user's remote IP to the whitelist (anti-lockout rule)
	local TTY_IP="$(who am i | awk '{print $NF}' | sed 's/[()]//g')"
	if [ -n "$TTY_IP" ]; then
		ufw allow from $TTY_IP comment 'Anti-lockout rule based on first install of UFW'
	fi
}

##
# Install firewalld
#
# CHANGELOG:
#   2026.03.16 - Switch awk to use $NF for better support
#
function install_firewalld() {
	package_install firewalld

	# Auto-add the current user's remote IP to the whitelist (anti-lockout rule)
	local TTY_IP="$(who am i | awk '{print $NF}' | sed 's/[()]//g')"
	if [ -n "$TTY_IP" ]; then
		# Anti-lockout rule based on first install of firewalld
		firewall-cmd --zone=trusted --add-source=$TTY_IP --permanent
	fi
}

##
# Install the system default firewall based on the OS type
#
# For Debian/Ubuntu, this installs UFW
# For RHEL/CentOS, this installs firewalld
# For SUSE, this installs firewalld
# For other OS types, this defaults to installing UFW
#
# CHANGELOG
#  2026.09.12 - Auto-install ipset along with firewall for working with sets of ips
#  2026.07.08 - Add support for Arch
#  2026.03.16 - Initial port from firewall-specific scripts
#
function firewall_install() {
	if [ "$(get_available_firewall)" == "none" ]; then
		# No firewall installed yet, install the distro default one

		if os_like_debian -q; then
			install_ufw
		elif os_like_rhel -q; then
			install_firewalld
		elif os_like_suse -q; then
			install_firewalld
		elif os_like_arch -q; then
			install_firewalld
		else
			install_ufw
		fi
	fi

	# Ensure ipset is installed; useful for blocklists
	package_install_if ipset
}
##
# Simple check to enforce the script to be run as root
if [ $(id -u) -ne 0 ]; then
	echo "This script must be run as root or with sudo!" >&2
	exit 1
fi
function usage() {
  cat >&2 <<EOD
Usage: $0 [options]

Options:
    --ip=<string> - IP address or CIDR network to allow DEFAULT=""
    --port=<string> - Port(s) to allow DEFAULT=""
    --proto=<tcp|udp> - Protocol to allow DEFAULT=tcp
    --comment=<comment> - Optional comment for the rule

Allow a service and/or source in the firewall.

Examples:
  Allow http/https - linux_util_firewall_allow.sh --port="80,443"
  Allow DNS - linux_util_firewall_allow.sh --port=53 --proto=udp
  Whitelist IP - linux_util_firewall_allow.sh --ip=5.4.5.4
  Allow IP to access port - linux_util_firewall_allow.sh --ip=5.4.5.4 --port=22
EOD
  exit 1
}

# Parse arguments
SOURCE=""
PORT=""
PROTO="tcp"
COMMENT=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--ip=*|--ip)
			[ "$1" == "--ip" ] && shift 1 && SOURCE="$1" || SOURCE="${1#*=}"
			[ "${SOURCE:0:1}" == "'" ] && [ "${SOURCE:0-1}" == "'" ] && SOURCE="${SOURCE:1:-1}"
			[ "${SOURCE:0:1}" == '"' ] && [ "${SOURCE:0-1}" == '"' ] && SOURCE="${SOURCE:1:-1}"
			;;
		--port=*|--port)
			[ "$1" == "--port" ] && shift 1 && PORT="$1" || PORT="${1#*=}"
			[ "${PORT:0:1}" == "'" ] && [ "${PORT:0-1}" == "'" ] && PORT="${PORT:1:-1}"
			[ "${PORT:0:1}" == '"' ] && [ "${PORT:0-1}" == '"' ] && PORT="${PORT:1:-1}"
			;;
		--proto=*|--proto)
			[ "$1" == "--proto" ] && shift 1 && PROTO="$1" || PROTO="${1#*=}"
			[ "${PROTO:0:1}" == "'" ] && [ "${PROTO:0-1}" == "'" ] && PROTO="${PROTO:1:-1}"
			[ "${PROTO:0:1}" == '"' ] && [ "${PROTO:0-1}" == '"' ] && PROTO="${PROTO:1:-1}"
			;;
		--comment=*|--comment)
			[ "$1" == "--comment" ] && shift 1 && COMMENT="$1" || COMMENT="${1#*=}"
			[ "${COMMENT:0:1}" == "'" ] && [ "${COMMENT:0-1}" == "'" ] && COMMENT="${COMMENT:1:-1}"
			[ "${COMMENT:0:1}" == '"' ] && [ "${COMMENT:0-1}" == '"' ] && COMMENT="${COMMENT:1:-1}"
			;;
		-h|--help) usage;;
		*) echo "Unknown argument: $1" >&2; usage;;
	esac
	shift 1
done


# Ensure dependencies are installed
firewall_install

FIREWALL_AVAILABLE="$(get_available_firewall)"
if [ "$FIREWALL_AVAILABLE" == "none" ]; then
	log_error "Firewall auto-install failed"
	exit 1
fi

firewall_action --action allow --port "$PORT" --source "$SOURCE" --comment "$COMMENT"
