#!/usr/bin/env python3
"""
Retrieve the public SSH key for a given user account

Syntax:
	--user=<str> - The user account to authorize the SSH key for DEFAULT=root
	--type=<str> - The SSH key to authorize DEFAULT=ecdsa

Supports:
	Linux-All

Category:
	User Management

Changelog:
	20250625 - Initial version

"""

import argparse

from scriptlets.ssh.get_user_public_key import ssh_get_user_public_key

# scriptlet:_common/require_root.py


parser = argparse.ArgumentParser(
	prog='linux_util_ssh_get_key.py',
	description='Retrieve the public SSH key for a given user account')
# compile:argparse
args = parser.parse_args()

print(ssh_get_user_public_key(args.user, args.type))