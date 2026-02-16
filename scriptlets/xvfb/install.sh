# scriptlet:_common/package_install.sh

##
# Install Xvfb and (optionally) a daemon helper
#
# Syntax:
#   install_xvfb [--no-daemon] [--display <int>] [--service <name>]
#
# Changelog:
#   20260216 - Initial version
#
function install_xvfb() {
	local SERVICE_DISPLAY=99
	local SERVICE_NAME="xvfb"
	local NO_DAEMON=0

	while [ $# -ge 1 ]; do
		case $1 in
			--no-daemon) NO_DAEMON=1;;
			--display) shift; SERVICE_DISPLAY="$1";;
			--service) shift; SERVICE_NAME="$1";;
		esac
		shift
	done

	package_install xvfb

	if [ "$NO_DAEMON" -eq 0 ]; then
		# Install the daemon helper script
		cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOL
[Unit]
Description=Virtual Frame Buffer (Xvfb)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb :${SERVICE_DISPLAY} -screen 0 1024x768x16 -nolisten tcp
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
		systemctl daemon-reload
		systemctl enable ${SERVICE_NAME}.service
		systemctl start ${SERVICE_NAME}.service

		echo "Xvfb service '${SERVICE_NAME}' installed and started on display :${SERVICE_DISPLAY}."
	fi
}
