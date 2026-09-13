# scriptlet: _common/os_like.sh
# scriptlet: _common/os_version.sh
# scriptlet: _common/cmd_exists.sh

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
