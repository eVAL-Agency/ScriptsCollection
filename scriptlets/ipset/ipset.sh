# scriptlet:_common/get_firewall.sh
# scriptlet:_common/package_install.sh
# scriptlet:bz_eval_log/log.sh

##
# Create an ipset of the requested type
#
# Will silently exit if the ipset already exists.
#
# CHANGELOG:
#   2026.09.28 - Fix for UFW on reboots for persistent ipsets
#   2026.09.15 - Minor fix for firewalld CLI syntax
#   2026.09.13 - Initial version
#
function ipset_create() {
	# Argument parsing
	local NAME=""
	local TYPE="hash:ip"
	local IS_TEMP=0
	local TIMEOUT=""
	local FIREWALL_AVAILABLE="$(get_available_firewall)"
	local TIMEOUT_CLI=""

	while [ $# -ge 1 ]; do
		case $1 in
			--name)
				shift
				NAME="$1"
				;;
			--type)
				shift
				TYPE="$1"
				;;
			--temp)
				IS_TEMP=1
				;;
			--timeout)
				shift
				TIMEOUT="$1"
				;;
		esac
		shift
	done

	if [ -z "$NAME" ] || [ -z "$TYPE" ]; then
		log_error "ipset_create: Missing required parameters!"
		return 1
	fi

	package_install_if ipset

	if [ -n "$TIMEOUT" ]; then
		TIMEOUT_CLI="timeout $TIMEOUT"
	fi

	if ! ipset --list "$NAME" >/dev/null 2>&1; then
		# Does not exist yet, create it!
		ipset create "$NAME" "$TYPE" $TIMEOUT_CLI

		if [ "$FIREWALL_AVAILABLE" == "firewalld" ]; then
			if [ $IS_TEMP -eq 0 ]; then
				firewall-cmd --permanent --new-ipset="$NAME" --type="$TYPE"
				firewall-cmd --reload
			fi
		fi
	fi

	if [ "$FIREWALL_AVAILABLE" == "ufw" ]; then
		# UFW requires some additional attention to ensure that ipset is persistent across restarts.
		if [ $IS_TEMP -eq 0 ]; then
			ipset save > /etc/ipset.save
		fi

		if [ ! -e "/etc/systemd/system/ipset-persistent.service" ]; then
			cat > "/etc/systemd/system/ipset-persistent.service" <<EOD
[Unit]
Description=Restore ipset rules
Before=network-pre.target ufw.service
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sh -c '[ -f /etc/ipset.save ] && ipset restore < /etc/ipset.save || true'
ExecStart=-/bin/true
ExecStopPost=/sbin/ipset save > /etc/ipset.save

[Install]
WantedBy=multi-user.target
EOD
		systemctl daemon-reload
		systemctl enable ipset-persistent.service
		fi
	fi
}


##
# Swap the contents of an ipset into another
#
# Will ensure the first exists and will auto-remove the temp list on migration
#
function ipset_swap() {
	# Argument parsing
	local ORIGINAL="$1"
	local TEMPORARY="$2"

	if [ -z "$ORIGINAL" ] || [ -z "$TEMPORARY" ]; then
		log_error "ipset_swap: Missing required parameters!"
		return 1
	fi

	package_install_if ipset
	if ! ipset --list "$ORIGINAL" >/dev/null 2>&1; then
		# Does not exist yet!
		return 1
	fi

	ipset swap "$ORIGINAL" "$TEMPORARY"
	ipset destroy "$TEMPORARY"
}
