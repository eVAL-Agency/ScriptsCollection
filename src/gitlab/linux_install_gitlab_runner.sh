#!/bin/bash
#
# Install Gitlab Runner [Linux]
#
# Syntax:
#   SERVER=--url=... - Fully resolved URL of Gitlab server, including http(s)://
#   GITLAB_TOKEN (environmental variable) - Registration token for the Gitlab server (REQUIRED)
#
# TRMM Arguments:
#   --server={{client.gitlab_server}}
#
# TRMM Environment:
#   GITLAB_TOKEN=some-generated-token-1234
#
# Supports:
#   AmazonLinux 2, 2023, 2025
#   CentOS 8, 9
#   Debian 11, 12, 13
#   LinuxMint
#   Raspbian
#   Rocky 8, 9
#   RHEL 7, 8, 9, 10
#   Ubuntu 24.04
#
# Category:
#   Software
#
# License:
#   AGPLv3
#
# Author:
#   Charlie Powell <cdp1337@bitsnbytes.dev>
#
# Link:
#   https://github.com/eVAL-Agency/ScriptsCollection
#
# @TRMM-TIMEOUT 120
#
# Changelog:
#   2026.09.22 - Original Release
#


# compile:usage
# compile:argparse
# scriptlet:_common/require_root.sh
# scriptlet:_common/os_like.sh
# scriptlet:_common/package_install.sh
# scriptlet:_common/download.sh
# scriptlet:bz_eval_log/log.sh
# scriptlet:docker/install_engine.sh

if [ -z "$GITLAB_TOKEN" ]; then
	log_error "Missing Gitlab token in environment variable GITLAB_TOKEN"
	exit 1
fi

# Install Docker as a dependency so Gitlab Runner has access to it.
install_docker_engine

# Generated from https://docs.gitlab.com/runner/install/linux-repository
SRC=""
FILE="gitlab-runner-repository.sh"

[ -e /opt/script-collection ] || mkdir -p /opt/script-collection

if os_like_debian -q; then
	SRC="https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh"
	if ! download "$SRC" "/opt/script-collection/$FILE" --no-overwrite; then
		log_error "Failed to download $SRC/$FILE"
		exit 1
	fi
elif os_like_rhel -q; then
	SRC="https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh"
	if ! download "$SRC" "/opt/script-collection/$FILE" --no-overwrite; then
		log_error "Failed to download $SRC/$FILE"
		exit 1
	fi
else
	log_error "Unable to install Gitlab Runner, unsupported or unknown OS"
	exit 1
fi

# Install the repo
chmod +x /opt/script-collection/$FILE
/opt/script-collection/$FILE

# Install the runner
package_install gitlab-runner

gitlab-runner register \
  --non-interactive \
  --url "$SERVER" \
  --token "$GITLAB_TOKEN" \
  --executor "docker" \
  --docker-image alpine:latest \
  --docker-pull-policy "if-not-present"
