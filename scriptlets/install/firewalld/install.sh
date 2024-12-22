# scriptlet: checks/os/os_like.sh

##
# Install firewalld
#
function install_firewalld() {
	TYPE_DEBIAN="$(os_like_debian)"
	TYPE_RHEL="$(os_like_rhel)"
	TYPE_ARCH="$(os_like_arch)"
	TYPE_SUSE="$(os_like_suse)"

	if [ "$TYPE_DEBIAN" == 1 ]; then
		apt update
		apt install -y firewalld
	elif [ "$TYPE_RHEL" == 1 ]; then
		dnf install -y firewalld
	elif [ "$TYPE_ARCH" == 1 ]; then
		pacman -Syu --noconfirm firewalld
	elif [ "$TYPE_SUSE" == 1 ]; then
		zypper ref
		zypper install -y firewalld
	else
		echo 'Unsupported or unknown OS' >&2
		exit 1
	fi
}
