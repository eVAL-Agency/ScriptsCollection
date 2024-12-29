# scriptlet: _common/package_install.sh

##
# Install firewalld
#
function install_firewalld() {
	package_install firewalld

	# Auto-add the current user's remote IP to the whitelist (anti-lockout rule)
	local TTY_IP="$(who am i | awk '{print $5}' | sed 's/[()]//g')"
	if [ -n "$TTY_IP" ]; then
		# Anti-lockout rule based on first install of firewalld
		firewall-cmd --zone=trusted --add-source=$TTY_IP --permanent
	fi
}
