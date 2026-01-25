# scriptlet:_common/cmd_exists.sh
# scriptlet:_common/package_install.sh
# scriptlet:_common/download.sh

##
# Install OpenJDK from Eclipse Adoptium
#
# https://github.com/adoptium
#
# @arg $1 string OpenJDK version to install
#
# Will print the directory where OpenJDK was installed.
#
# CHANGELOG:
#   2026.01.13 - Initial version
#
function install_openjdk() {
	local VERSION="${1:-25}"

	# Validate version input
	if ! echo "$VERSION" | grep -E -q '^(8|11|16|17|18|19|20|21|22|23|24|25|26|27)$'; then
		echo "install_openjdk: Invalid OpenJDK version specified: $VERSION" >&2
		echo "Supported versions are: 8, 11, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27" >&2
		return 1
	fi

	if ! cmd_exists curl; then
		package_install curl
	fi

	# We will use this directory as a working directory for source files that need downloaded.
	[ -d /opt/script-collection ] || mkdir -p /opt/script-collection

	local DOWNLOAD_URL="$(curl https://api.github.com/repos/adoptium/temurin${VERSION}-binaries/releases/latest \
	  | grep browser_download_url \
	  | grep jre_x64_linux \
	  | grep 'tar\.gz"' \
	  | cut -d : -f 2,3 \
	  | tr -d \"\
	  | sed 's:\s*::')"

	local JDK_TGZ="$(basename "$DOWNLOAD_URL")"

	if ! download "$DOWNLOAD_URL" "/opt/script-collection/$JDK_TGZ" --no-overwrite; then
		echo "install_openjdk: Cannot download OpenJDK from ${DOWNLOAD_URL}!" >&2
		return 1
	fi

	local JDK_DIR="$(tar -zf "/opt/script-collection/$JDK_TGZ" --list | head -1)"

	if [ ! -e "/opt/script-collection/$JDK_DIR" ]; then
		tar -x -C /opt/script-collection/ -f "/opt/script-collection/$JDK_TGZ"
	fi

	echo "/opt/script-collection/$JDK_TGZ"
}

