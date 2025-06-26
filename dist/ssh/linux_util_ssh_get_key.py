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
import os
from typing import Union
import pwd
import logging
import ctypes



def ssh_get_user_public_key(username: str, key_type: str = 'ecdsa') -> Union[str,None]:
	"""
	Get the public key for a given user

	If the requested type of key is not found, it will be created automatically.

	:param username: The username to retrieve the public key for
	:param key_type: The type of key to retrieve (e.g., 'ecdsa', 'rsa', etc.)
	:return: str
	"""
	try:
		home = pwd.getpwnam(username).pw_dir
		uid = pwd.getpwnam(username).pw_uid
		gid = pwd.getpwnam(username).pw_gid
	except KeyError:
		logging.error('Username [%s] not found!' % username)
		return None

	valid_type_types = ['dsa', 'rsa', 'ecdsa', 'ecdsa-sk', 'ed25519', 'ed25519-sk']
	if key_type not in valid_type_types:
		logging.error('Invalid key type [%s] specified. Valid types are: %s' % (key_type, ', '.join(valid_type_types)))
		return None

	path = os.path.join(home, '.ssh')
	if not os.path.exists(path):
		# Auto-create directory if necessary
		os.mkdir(path)
		os.chmod(path, 0o700)
		os.chown(path, uid, gid)

	key_path = os.path.join(home, '.ssh', 'id_' + key_type + '.pub')
	if not os.path.exists(key_path):
		# Auto-create key if it does not exist
		private_path = key_path[:-4]
		logging.info('Public key for user [%s] of type [%s] does not exist, generating new key.' % (username, key_type))
		os.system(f'ssh-keygen -q -t {key_type} -f {private_path} -N ""')
		os.chmod(key_path, 0o644)
		os.chown(key_path, uid, gid)
		os.chmod(private_path, 0o600)
		os.chown(private_path, uid, gid)

	# Read the public key
	with open(key_path, 'r') as f:
		return f.read().strip()

##
# Simple check to enforce the script to be run as root

try:
	if os.getuid() != 0:
		print("This script must be run as root!")
		exit(1)
except AttributeError:
	# Windows doesn't have os.getuid
	if not ctypes.windll.shell32.IsUserAnAdmin():
		print("This script must be run with administrative privileges!")
		exit(1)


parser = argparse.ArgumentParser(
	prog='linux_util_ssh_get_key.py',
	description='Retrieve the public SSH key for a given user account')
# Parse arguments
parser.add_argument('--user', type=str, help='The user account to authorize the SSH key for', default='root')
parser.add_argument('--type', type=str, help='The SSH key to authorize', default='ecdsa')

args = parser.parse_args()

print(ssh_get_user_public_key(args.user, args.type))