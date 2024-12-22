##
# Get the operating system
# freebsd, centos, redhat, fedora, ubuntu, debian, arch, suse, amazon
function os() {
	if [ "$(uname -s)" == 'FreeBSD' ]; then
		echo 'freebsd'

	elif [ -f '/etc/os-release' ]; then
		echo "$(egrep '^ID=' /etc/os-release | sed 's:ID=::')"

	else
		echo 'unknown'
	fi
}
