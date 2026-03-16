# scriptlet:_common/get_firewall.sh
# scriptlet:_common/os_like.sh
# scriptlet:ufw/install.sh
# scriptlet:firewalld/install.sh

##
# Install the system default firewall based on the OS type
#
# For Debian/Ubuntu, this installs UFW
# For RHEL/CentOS, this installs firewalld
# For SUSE, this installs firewalld
# For other OS types, this defaults to installing UFW
#
function firewall_install() {
	local FIREWALL

	FIREWALL=$(get_available_firewall)
	if [ "$FIREWALL" != "none" ]; then
		return
	fi

	if os_like_debian -q; then
		install_ufw
	elif os_like_rhel -q; then
		install_firewalld
	elif os_like_suse -q; then
		install_firewalld
	else
		install_ufw
	fi
}
