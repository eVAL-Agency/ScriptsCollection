##
# Simple download utility function
#
# Uses either cURL or wget based on which is available
#
# Returns 0 on success, 1 on failure
function download() {
	local SOURCE="$1"
	local DESTINATION="$2"

	if [ -z "$SOURCE" ] || [ -z "$DESTINATION" ]; then
		echo "download: Missing required parameters!" >&2
		return 1
	fi

	if [ -n "$(which curl)" ]; then
		if curl -fsL "$SOURCE" -o "$DESTINATION"; then
			return 0
		else
			echo "download: curl failed to download $SOURCE" >&2
			return 1
		fi
	elif [ -n "$(which wget)" ]; then
		if wget -q "$SOURCE" -O "$DESTINATION"; then
			return 0
		else
			echo "download: wget failed to download $SOURCE" >&2
			return 1
		fi
	else
		echo "download: Neither curl nor wget is installed, cannot download!" >&2
		return 1
	fi
}
