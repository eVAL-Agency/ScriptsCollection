##
# Install Glorious Eggroll's Proton fork on a requested version
#
# https://github.com/GloriousEggroll/proton-ge-custom
#
# Will install Proton into /opt/script-collection/GE-Proton${VERSION}
# with its pfx directory in /opt/script-collection/GE-Proton${VERSION}/files/share/default_pfx
#
# @arg $1 string Proton version to install
function install_proton() {
	VERSION="${1:-9-21}"

	echo "Installing Glorious Eggroll's Proton $VERSION..."

	PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${VERSION}/GE-Proton${VERSION}.tar.gz"
	PROTON_TGZ="$(basename "$PROTON_URL")"
	PROTON_NAME="$(basename "$PROTON_TGZ" ".tar.gz")"

	# We will use this directory as a working directory for source files that need downloaded.
	[ -d /opt/script-collection ] || mkdir -p /opt/script-collection

	# Grab Proton from Glorious Eggroll
	if [ ! -e "/opt/script-collection/$PROTON_TGZ" ]; then
		wget "$PROTON_URL" -O "/opt/script-collection/$PROTON_TGZ"
	fi
	# Extract GE Proton into /opt
	if [ ! -e "/opt/script-collection/$PROTON_NAME" ]; then
		tar -x -C /opt/script-collection/ -f "/opt/script-collection/$PROTON_TGZ"
	fi
}
