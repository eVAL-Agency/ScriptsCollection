# scriptlet: _common/os_like.sh
# scriptlet: _common/os_version.sh
# scriptlet: _common/cmd_exists.sh

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
#   2026.07.08 - Add paru support for Arch's AUR
#   2026.01.09 - Cleanup os_like a bit and add support for RHEL 9's dnf
#   2025.04.10 - Set Debian frontend to noninteractive
#
function package_install (){
	echo "package_install: Installing $*..."

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
		if ! cmd_exists paru; then
			# Install paru before handling the user packages
			_package_install_paru
		fi
		paru -Syu --noconfirm $*
	elif os_like_suse -q; then
		zypper install -y $*
	else
		echo 'package_install: Unsupported or unknown OS' >&2
		echo 'Please report this at https://github.com/eVAL-Agency/ScriptsCollection/issues' >&2
		exit 1
	fi
}

##
# Special handler to ensure paru is installed on an Arch system.
#
# Useful to allow packages to install from the AUR by default.
#
function _package_install_paru() {
	pacman -S git base-devel make

	[ -e /opt/script-collection/ ] || mkdir -p /opt/script-collection
	if [ ! -e /opt/script-collection/paru ]; then
		git clone https://aur.archlinux.org/paru.git /opt/script-collection/paru
	fi

	cd /opt/script-collection/paru
	makepkg -si
	cd -
}
