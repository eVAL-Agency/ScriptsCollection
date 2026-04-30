# scriptlet:_common/cmd_exists.sh
# scriptlet:bz_eval_log/log.sh

##
# Simple download utility function
#
# Uses either cURL or wget based on which is available
#
# Downloads the file to a temp location initially, then moves it to the final destination
# upon a successful download to avoid partial files.
#
# Returns 0 on success, 1 on failure
#
# Arguments:
#   --no-overwrite       Skip download if destination file already exists
#
# CHANGELOG:
#   2026.04.30 - Use logging with new logging interface
#   2026.04.21 - Add retry in curl to retry on connection issues, (looking at you Github)
#   2025.12.15 - Use cmd_exists to fix regression bug
#   2025.12.04 - Add --no-overwrite option to allow skipping download if the destination file exists
#   2025.11.23 - Download to a temp location to verify download was successful
#              - use which -s for cleaner checks
#   2025.11.09 - Initial version
#
function download() {
	# Argument parsing
	local SOURCE="$1"
	local DESTINATION="$2"
	local OVERWRITE=1
	local TMP=$(mktemp)
	shift 2

	while [ $# -ge 1 ]; do
    		case $1 in
    			--no-overwrite)
    				OVERWRITE=0
    				;;
    		esac
    		shift
    	done

	if [ -z "$SOURCE" ] || [ -z "$DESTINATION" ]; then
		log_error "download: Missing required parameters!"
		return 1
	fi

	if [ -f "$DESTINATION" ] && [ $OVERWRITE -eq 0 ]; then
		log_info "download: Destination file $DESTINATION already exists, skipping download."
		return 0
	fi

	if cmd_exists curl; then
		log_debug "download: Attempting to curl download $SOURCE"
		if curl --connect-timeout 10 --retry 3 --retry-delay 10 -fsL "$SOURCE" -o "$TMP"; then
			log_debug "download: Download successful, moving file to $DESTINATION"
			mv $TMP "$DESTINATION"
			return 0
		else
			log_error "download: curl failed to download $SOURCE"
			return 1
		fi
	elif cmd_exists wget; then
		log_debug "download: Attempting to wget download $SOURCE"
		if wget -q "$SOURCE" -O "$TMP"; then
			log_debug "download: Download successful, moving file to $DESTINATION"
			mv $TMP "$DESTINATION"
			return 0
		else
			log_error "download: wget failed to download $SOURCE"
			return 1
		fi
	else
		log_error "download: Neither curl nor wget is installed, cannot download!"
		return 1
	fi
}
