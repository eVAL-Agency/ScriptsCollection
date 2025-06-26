import os
from typing import Union
import pwd
import logging


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
