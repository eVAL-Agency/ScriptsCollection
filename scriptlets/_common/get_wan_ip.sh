##
# Try to retrieve the WAN IP of this device based on ipify.org
function get_wan_ip() {
	if [ -n "$(which curl)" ]; then
		curl -s https://api.ipify.org
	elif [ -n "$(which wget)" ]; then
		wget -qO- https://api.ipify.org
	else
		echo "Error: Please install either curl or wget" >&2
		return 1
	fi
}
