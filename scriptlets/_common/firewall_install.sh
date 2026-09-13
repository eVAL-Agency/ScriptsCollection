# scriptlet:_common/get_firewall.sh
# scriptlet:_common/os_like.sh
# scriptlet:ufw/install.sh
# scriptlet:firewalld/install.sh
# scriptlet:_common/package_install.sh
# scriptlet:_common/cmd_exists.sh

##
# Install the system default firewall based on the OS type
#
# For Debian/Ubuntu, this installs UFW
# For RHEL/CentOS, this installs firewalld
# For SUSE, this installs firewalld
# For other OS types, this defaults to installing UFW
#
# CHANGELOG
#  2026.09.12 - Auto-install ipset along with firewall for working with sets of ips
#  2026.07.08 - Add support for Arch
#  2026.03.16 - Initial port from firewall-specific scripts
#
function firewall_install() {
	if [ "$(get_available_firewall)" == "none" ]; then
		# No firewall installed yet, install the distro default one

		if os_like_debian -q; then
			install_ufw
		elif os_like_rhel -q; then
			install_firewalld
		elif os_like_suse -q; then
			install_firewalld
		elif os_like_arch -q; then
			install_firewalld
		else
			install_ufw
		fi
	fi

	# Ensure ipset is installed; useful for blocklists
	package_install_if ipset
}
