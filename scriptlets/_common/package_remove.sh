# scriptlet: _common/os_like.sh

##
# Remove a package with the system's package manager.
#
# Uses Redhat's yum, Debian's apt-get, and SuSE's zypper.
#
# Usage:
#
# ```syntax-shell
# package_remove apache2
# ```
#
# @param $1..$N string
#        Package, (or packages), to remove.  Accepts multiple packages at once.
#
function package_remove (){
	echo "package_remove: Removing $*..."

	TYPE_BSD="$(os_like_bsd)"
	TYPE_DEBIAN="$(os_like_debian)"
	TYPE_RHEL="$(os_like_rhel)"
	TYPE_ARCH="$(os_like_arch)"
	TYPE_SUSE="$(os_like_suse)"

	if [ "$TYPE_BSD" == 1 ]; then
		pkg remove -y $*
	elif [ "$TYPE_DEBIAN" == 1 ]; then
		apt-get remove -y $*
	elif [ "$TYPE_RHEL" == 1 ]; then
		yum remove -y $*
	elif [ "$TYPE_ARCH" == 1 ]; then
		pacman -Rns --noconfirm $*
	elif [ "$TYPE_SUSE" == 1 ]; then
		zypper remove -y $*
	else
		echo 'package_remove: Unsupported or unknown OS' >&2
		echo 'Please report this at https://github.com/cdp1337/ScriptsCollection/issues' >&2
		exit 1
	fi
}
