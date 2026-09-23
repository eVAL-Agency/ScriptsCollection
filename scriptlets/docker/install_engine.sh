# scriptlet:_common/os_like.sh
# scriptlet:_common/os_codename.sh
# scriptlet:_common/package_install.sh
# scriptlet:bz_eval_log/log.sh


##
# Install Docker Engine
#
# Generated from https://docs.docker.com/engine/install/ubuntu/
#
# Changelog:
#   2026.09.22 - Original Release
#
function install_docker_engine() {
	if os_like_debian -q; then
		local KEY_SRC="https://download.docker.com/linux/debian/gpg"
		local DEB_SRC="https://download.docker.com/linux/debian"
		local CODENAME="$(os_codename)"
		if os_like_ubuntu -q; then
			KEY_SRC="https://download.docker.com/linux/ubuntu/gpg"
			DEB_SRC="https://download.docker.com/linux/ubuntu"
    	fi

    	package_install ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL $KEY_SRC -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: $DEB_SRC
Suites: $CODENAME
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

		apt update
		package_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		return 0
	elif os_like_fedora -q; then
		dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
		package_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		systemctl enable --now docker
		return 0
	elif os_like_rhel -q; then
		package_install dnf-plugins-core
		dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
		package_install install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		systemctl enable --now docker
		return 0
	else
		log_error "Unable to determine OS for Docker Engine install"
		return 1
	fi
}
