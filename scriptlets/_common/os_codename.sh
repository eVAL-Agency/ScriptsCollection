##
# Get the operating system codename
#
# This returns the name of the os, generally used in repositories
#
# Debian may return "trixie" or "bullseye".
#
function os_codename() {
	if [ -f '/etc/os-release' ]; then
		local VERS="$(grep -E '^VERSION_CODENAME=' /etc/os-release | sed 's:VERSION_CODENAME=::')"

		if [[ "$VERS" =~ '"' ]]; then
			# Strip quotes around the OS codename
			VERS="$(echo "$VERS" | sed 's:"::g')"
		fi

		echo "$VERS"

	else
		echo ''
	fi
}
