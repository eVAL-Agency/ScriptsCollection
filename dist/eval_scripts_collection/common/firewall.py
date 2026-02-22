import sys
import subprocess

def get_enabled_firewall() -> str:
	"""
	Returns the name of the enabled firewall on the system.
	Checks for UFW, Firewalld, and iptables in that order.

	Returns:
		str: The name of the enabled firewall ('ufw', 'firewalld', 'iptables') or 'none' if none are enabled.
	"""

	# Check for UFW
	try:
		ufw_status = subprocess.run(['ufw', 'status'], capture_output=True, text=True)
		if 'Status: active' in ufw_status.stdout:
			return 'ufw'
	except FileNotFoundError:
		pass

	# Check for Firewalld
	try:
		firewalld_status = subprocess.run(['firewall-cmd', '--state'], capture_output=True, text=True)
		if 'running' in firewalld_status.stdout:
			return 'firewalld'
	except FileNotFoundError:
		pass

	# Check for iptables
	try:
		iptables_status = subprocess.run(['iptables', '-L'], capture_output=True, text=True)
		if iptables_status.returncode == 0:
			return 'iptables'
	except FileNotFoundError:
		pass

	return 'none'

def get_available_firewall() -> str:
	"""
	Returns the name of the available firewall on the system.
	Checks for UFW, Firewalld, and iptables in that order.

	Returns:
		str: The name of the available firewall ('ufw', 'firewalld', 'iptables') or 'none' if none are available.
	"""

	# Check for UFW
	try:
		subprocess.run(['ufw', '--version'], capture_output=True, text=True)
		return 'ufw'
	except FileNotFoundError:
		pass

	# Check for Firewalld
	try:
		subprocess.run(['firewall-cmd', '--version'], capture_output=True, text=True)
		return 'firewalld'
	except FileNotFoundError:
		pass

	# Check for iptables
	try:
		subprocess.run(['iptables', '--version'], capture_output=True, text=True)
		return 'iptables'
	except FileNotFoundError:
		pass

	return 'none'

def firewall_allow(port: int, protocol: str = 'tcp', comment: str = None) -> None:
	"""
	Allows a specific port through the system's firewall.
	Supports UFW, Firewalld, and iptables.

	Args:
		port (int): The port number to allow.
		protocol (str, optional): The protocol to use ('tcp' or 'udp'). Defaults to 'tcp'.
		comment (str, optional): An optional comment for the rule. Defaults to None.
	"""

	firewall = get_available_firewall()

	if firewall == 'ufw':
		cmd = ['ufw', 'allow', f'{port}/{protocol}']
		if comment:
			cmd.extend(['comment', comment])
		subprocess.run(cmd, check=True)

	elif firewall == 'firewalld':
		cmd = ['firewall-cmd', '--permanent', '--add-port', f'{port}/{protocol}']
		subprocess.run(cmd, check=True)
		subprocess.run(['firewall-cmd', '--reload'], check=True)

	elif firewall == 'iptables':
		cmd = ['iptables', '-A', 'INPUT', '-p', protocol, '--dport', str(port), '-j', 'ACCEPT']
		if comment:
			cmd.extend(['-m', 'comment', '--comment', comment])
		subprocess.run(cmd, check=True)
		subprocess.run(['service', 'iptables', 'save'], check=True)

	else:
		print('No supported firewall found on the system.', file=sys.stderr)

def firewall_remove(port: int, protocol: str = 'tcp') -> None:
	"""
	Removes a specific port from the system's firewall.
	Supports UFW, Firewalld, and iptables.

	Args:
		port (int): The port number to remove.
		protocol (str, optional): The protocol to use ('tcp' or 'udp'). Defaults to 'tcp'.
	"""

	firewall = get_available_firewall()

	if firewall == 'ufw':
		cmd = ['ufw', 'delete', 'allow', f'{port}/{protocol}']
		subprocess.run(cmd, check=True)

	elif firewall == 'firewalld':
		cmd = ['firewall-cmd', '--permanent', '--remove-port', f'{port}/{protocol}']
		subprocess.run(cmd, check=True)
		subprocess.run(['firewall-cmd', '--reload'], check=True)

	elif firewall == 'iptables':
		cmd = ['iptables', '-D', 'INPUT', '-p', protocol, '--dport', str(port), '-j', 'ACCEPT']
		subprocess.run(cmd, check=True)
		subprocess.run(['service', 'iptables', 'save'], check=True)

	else:
		raise RuntimeError("No supported firewall found on the system.")
