##
# Determine if the current shell session is non-interactive.
#
# Checks NONINTERACTIVE, CI, DEBIAN_FRONTEND, and TERM.
#
# Returns 0 (true) if non-interactive, 1 (false) if interactive.
#
# CHANGELOG:
#   2025.12.16 - Remove TTY checks to avoid false positives in some environments
#   2025.11.23 - Initial version
#
function is_noninteractive() {
	# explicit flags
	case "${NONINTERACTIVE:-}${CI:-}" in
		1*|true*|TRUE*|True*|*CI* ) return 0 ;;
	esac

	# debian frontend
	if [ "${DEBIAN_FRONTEND:-}" = "noninteractive" ]; then
		return 0
	fi

	# dumb terminal
	if [ "${TERM:-}" = "dumb" ]; then
		return 0
	fi

	return 1
}
