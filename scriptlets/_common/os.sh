##
# Get the operating system
#
# almalinux, alpine, amzn, antergos, arch, archarm, arcolinux,
# centos, clear-linux-os, clearos,
# debian,
# elementary, endeavouros,
# fedora, freebsd,
# gentoo,
# kali,
# linuxmint,
# mageia, manjaro,
# nixos,
# opensuse, ol,
# pop,
# raspbian, rhel, rocky,
# scientific, slackware, sles,
# ubuntu,
# virtuozzo
#
function os() {
	if [ "$(uname -s)" == 'FreeBSD' ]; then
		echo 'freebsd'

	elif [ -f '/etc/os-release' ]; then
		local DISTRO="$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"

		if [[ "$DISTRO" =~ '"' ]]; then
			# Strip quotes around the OS name
			DISTRO="$(echo "$DISTRO" | sed 's:"::g')"
		fi

		# Cleanup a few known distro names
		if [ "$DISTRO" == "manjaro-arm" ]; then
			# Manjaro on ARM
			DISTRO="manjaro"
		elif [ "$DISTRO" == "opensuse-leap" ]; then
			# OpenSuSE Leap 15.x
			DISTRO="opensuse"
		elif [ "$DISTRO" == "sles_sap" ]; then
			# SuSE Enterprise SAP 12.x
			DISTRO="sles"
		fi

		echo "$DISTRO"

	else
		echo 'unknown'
	fi
}
