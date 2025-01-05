import os
import pwd


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
