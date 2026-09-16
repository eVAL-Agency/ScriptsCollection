# scriptlet:_common/cmd_exists.sh

##
# Get which firewall is enabled or "none" if none currently active
#
# CHANGELOG:
#   2026.09.16 - Add support for ProxmoxVE Firewall
#
function get_enabled_firewall() {
	if [ "$(systemctl is-active firewalld)" == "active" ]; then
		echo "firewalld"
	elif [ "$(systemctl is-active ufw)" == "active" ]; then
		echo "ufw"
	elif cmd_exists pvesh && [ "$(pve-firewall status)" == "Status: enabled/running" ]; then
		echo "proxmox"
	elif [ "$(systemctl is-active iptables)" == "active" ]; then
		echo "iptables"
	else
		echo "none"
	fi
}

##
# Get which firewall is available on the local system or "none" if none located
#
# CHANGELOG:
#   2026.09.16 - Add support for ProxmoxVE Firewall
#   2025.12.15 - Use cmd_exists to fix regression bug
#   2025.04.10 - Switch from "systemctl list-unit-files" to "which" to support older systems
#
function get_available_firewall() {
	if cmd_exists firewall-cmd; then
		echo "firewalld"
	elif cmd_exists ufw; then
		echo "ufw"
	elif cmd_exists pvesh; then
	   echo "proxmox"
	elif cmd_exists iptables; then
		echo "iptables"
	else
		echo "none"
	fi
}
