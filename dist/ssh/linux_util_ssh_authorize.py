#!/usr/bin/env python3
"""
Authorize SSH Key [Linux]

Syntax:
	--user=<username> - The user account to authorize the SSH key for
	--key=<public key> - The SSH key to authorize
	--comment=<string> - [optional comment] - Optional comment to attribute with this key

Supports:
	Linux-All

Category:
	User Management

Changelog:
	20250105 - Initial version

"""
import os
import argparse
import pwd
import sys
import ctypes




def ssh_get_user_authorized_keys(username: str) -> list:
	"""
	Get the authorized keys for a given user

	:param username:
	:return: list(dict(key, comment))
	"""
	try:
		home = pwd.getpwnam(username).pw_dir
	except KeyError:
		return []

	authorized_keys = os.path.join(home, '.ssh', 'authorized_keys')
	if not os.path.exists(authorized_keys):
		return []

	keys = []
	last_comment = None
	with open(authorized_keys, 'r') as f:
		for line in f:
			if line.startswith('#'):
				last_comment = line[1:].strip()
			elif line.strip() != '':
				keys.append({'key': line.strip(), 'comment': last_comment})
				last_comment = None

	return keys

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
	prog='linux_util_ssh_authorize.py',
	description='Authorize an SSH key for a given user account')

parser.add_argument('--user', type=str, help='The user account to authorize the SSH key for')
parser.add_argument('--key', type=str, help='The SSH key to authorize')
parser.add_argument('--comment', type=str, help='Optional comment to attribute with this key', default='')

args = parser.parse_args()

try:
	home = pwd.getpwnam(args.user).pw_dir
	uid = pwd.getpwnam(args.user).pw_uid
	gid = pwd.getpwnam(args.user).pw_gid
except KeyError:
	print('User not found', file=sys.stderr)
	exit(1)

if not os.path.exists(os.path.join(home, '.ssh')):
	os.mkdir(os.path.join(home, '.ssh'))
	os.chmod(os.path.join(home, '.ssh'), 0o700)
	os.chown(os.path.join(home, '.ssh'), uid, gid)

authorized_keys = os.path.join(home, '.ssh', 'authorized_keys')
if not os.path.exists(authorized_keys):
	with open(authorized_keys, 'w') as f:
		f.write('')
	os.chmod(authorized_keys, 0o600)
	os.chown(authorized_keys, uid, gid)

keys = ssh_get_user_authorized_keys(args.user)
found = False
for key in keys:
	if key['key'] == args.key:
		found = True
		break

if not found:
	keys.append({'key': args.key, 'comment': args.comment})
	with open(authorized_keys, 'a') as f:
		for key in keys:
			if key['comment'] != '' and key['comment'] is not None:
				f.write('# ' + key['comment'] + '\n')
			f.write(key['key'] + '\n\n')
	print('Key authorized', file=sys.stderr)
else:
	print('Key already authorized', file=sys.stderr)
