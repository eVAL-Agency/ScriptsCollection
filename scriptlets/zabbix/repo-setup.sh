# scriptlet:_common/os.sh
# scriptlet:_common/os_version.sh
# scriptlet:_common/os_like.sh
# scriptlet:yum/repo_excludepkg.sh
# scriptlet:_common/package_install.sh

##
# Setup the Zabbix repo for this OS, shared between agent, agent2, server, and proxy.
function zabbix_repo_setup() {
	local ZABBIX_VERSION="$1"
	local OS_NAME="$(os)"
	local OS_VERSION="$(os_version)"
	local BASE="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}"

	if [ -z "$(which wget)" ]; then
		package_install wget
	fi

	case "${ZABBIX_VERSION}_${OS_NAME}" in
		"7.2_almalinux" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/alma/${OS_VERSION}/noarch/zabbix-release-latest-7.2.el${OS_VERSION}.noarch.rpm";;
		"7.2_debian" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.2+debian${OS_VERSION}_all.deb";;
		"7.2_raspbian" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/raspbian/pool/main/z/zabbix-release/zabbix-release_latest_7.2+debian${OS_VERSION}_all.deb";;
		"7.2_rhel" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/rhel/${OS_VERSION}/noarch/zabbix-release-latest-7.2.el${OS_VERSION}.noarch.rpm";;
		"7.2_rocky" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/rocky/${OS_VERSION}/noarch/zabbix-release-latest-7.2.el${OS_VERSION}.noarch.rpm";;
		"7.2_ubuntu" ) local SRC="https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu${OS_VERSION}.04_all.deb";;

		"7.0_almalinux" ) local SRC="https://repo.zabbix.com/zabbix/7.0/alma/${OS_VERSION}/x86_64/zabbix-release-latest-7.0.el${OS_VERSION}.noarch.rpm";;
		"7.0_debian" ) local SRC="https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian${OS_VERSION}_all.deb";;
		"7.0_raspbian" ) local SRC="https://repo.zabbix.com/zabbix/7.0/raspbian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian${OS_VERSION}_all.deb";;
		"7.0_rhel" ) local SRC="https://repo.zabbix.com/zabbix/7.0/rhel/${OS_VERSION}/x86_64/zabbix-release-latest-7.0.el${OS_VERSION}.noarch.rpm";;
		"7.0_rocky" ) local SRC="https://repo.zabbix.com/zabbix/7.0/rocky/${OS_VERSION}/x86_64/zabbix-release-latest-7.0.el${OS_VERSION}.noarch.rpm";;
		"7.0_ubuntu" ) local SRC="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu${OS_VERSION}.04_all.deb";;

		"6.0_almalinux" ) local SRC="https://repo.zabbix.com/zabbix/6.0/rhel/${OS_VERSION}/x86_64/zabbix-release-latest-6.0.el${OS_VERSION}.noarch.rpm";;
		"6.0_debian" ) local SRC="https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_6.0+debian${OS_VERSION}_all.deb";;
		"6.0_raspbian" ) local SRC="https://repo.zabbix.com/zabbix/6.0/raspbian/pool/main/z/zabbix-release/zabbix-release_latest_6.0+debian${OS_VERSION}_all.deb";;
		"6.0_rhel" ) local SRC="https://repo.zabbix.com/zabbix/6.0/rhel/${OS_VERSION}/x86_64/zabbix-release-latest-6.0.el${OS_VERSION}.noarch.rpm";;
		"6.0_rocky" ) local SRC="https://repo.zabbix.com/zabbix/6.0/rocky/${OS_VERSION}/x86_64/zabbix-release-latest-6.0.el${OS_VERSION}.noarch.rpm";;
		"6.0_ubuntu" ) local SRC="https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_6.0+ubuntu${OS_VERSION}.04_all.deb";;
	esac

	local FILE="$(basename "$SRC")"

	# We will use this directory as a working directory for source files that need downloaded.
	[ -d /opt/script-collection ] || mkdir -p /opt/script-collection

	if [ ! -e /opt/script-collection/$FILE ]; then
		wget $SRC -O /opt/script-collection/$FILE
		if [ $? -ne 0 ]; then
			echo "Failed to download $SRC" >&2
			exit 1
		fi

		if [ $(os_like_debian) -eq 1 ]; then
			dpkg -i /opt/script-collection/$FILE
			apt update
		elif [ $(os_like_rhel) -eq 1 ]; then
			yum_repo_excludepkg /etc/yum.repos.d/epel.repo "zabbix*"
			rpm -Uvh /opt/script-collection/$FILE
			dnf clean all
		else
			echo "Unable to install $_FILE, unsupported OS [ $OS ] version [ $OSVERSIONMAJ ]" >&2
		fi
	fi
}
