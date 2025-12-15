# scriptlet:_common/cmd_exists.sh

##
# Try to retrieve the WAN IP of this device based on ipify.org
#
# CHANGELOG:
#   2025.12.15 - Use cmd_exists to fix regression bug
#   2025.11.23 - use which -s for cleaner checks
#   2025.11.09 - Initial version
#
function get_wan_ip() {
	if cmd_exists curl; then
		curl -s https://api.ipify.org
	elif cmd_exists wget; then
		wget -qO- https://api.ipify.org
	else
		echo "Error: Please install either curl or wget" >&2
		return 1
	fi
}
