##
# Prompt user for a yes or no response
#
# Arguments:
#   --invert            Invert the response (yes becomes 0, no becomes 1)
#   --default-yes       Default to yes if no response is given
#   --default-no        Default to no if no response is given
#
# Returns:
#   1 for yes, 0 for no (or inverted if --invert is set)
#
function prompt_yn() {
	local YES=1
	local NO=0
	local DEFAULT="n"
	local PROMPT="Yes or no?"
	local RESPONSE=""

	while [ $# -ge 1 ]; do
		case $1 in
			--invert) YES=0; NO=1;;
			--default-yes) DEFAULT="y";;
			--default-no) DEFAULT="n";;
			*) PROMPT="$1";;
		esac
		shift
	done

	echo "$PROMPT" >&2
	if [ "$DEFAULT" == "y" ]; then
		DEFAULT="$YES"
		echo -n "> (Y/n): " >&2
	else
		DEFAULT="$NO"
		echo -n "> (y/N): " >&2
	fi
	read RESPONSE
	case "$RESPONSE" in
		[yY]*) echo $YES ;;
		[nN]*) echo $NO ;;
		*) echo $DEFAULT;;
	esac
}
