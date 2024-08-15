#!/opt/tacticalagent/toolbox/sys_info_api/bin/python3
"""
Install the Zabbix agent or proxy on a Linux endpoint.

Supports:
	Debian 10 - 12
	Rocky Linux 8, 9
	Ubuntu 18.04 - 24.04

Requirements:
	sys_info_api must be installed within the TRMM toolbox

TRMM Custom Fields:
	client.zabbix_hostname - Monitoring server for the specific client
	agent.fqdn - Fully qualified domain name of the endpoint (because rarely is it actually set correctly)
	agent.zabbix_role - Role of the endpoint (proxy|agent)

Args:
	None

Environment Variables:
	SERVER: The hostname of the Zabbix server to connect to
	HOSTNAME: The fully qualified domain name of the endpoint
	ROLE: The role of the endpoint (defaults to "agent" if not set)

License:
	GNU Affero General Public License

Author:
	Charlie Powell <cdp1337@veraciousnetwork.com>

Changelog:
	2024.08.NN - Original Release
"""

import os
import sys
import re
import pwd
import grp
from urllib.request import urlretrieve

from sys_info_api.device import operating_system
from sys_info_api.collectors.etc.yum_repos import YumRepos
from sys_info_api.collectors.bin.rpm import RpmInstall
from sys_info_api.collectors.bin.dpkg import DpkgInstall
from sys_info_api.collectors.bin.apt import AptInstall
from sys_info_api.collectors.bin.yum import YumInstall
from sys_info_api.collectors.bin.systemctl import SystemCtlService


def usage():
	print('Usage: Linux_Install_Zabbix.py')
	print('')
	print('Environmental Variables:')
	print('  HOSTNAME: Local device fully qualified hostname')
	print('    SERVER: Zabbix hostname to connect to')
	print('      ROLE: Role this device should perform, (proxy|agent)')
	sys.exit(1)


class ZabbixConfig:
	def __init__(self, filename: str):
		self.filename = filename
		self.lines = []
		self.fields = {}

		i = 0
		with open(filename, 'r') as f:
			for line in f:
				self.lines.append(line)
				if re.match(r'^[a-zA-Z0-9]+=', line):
					# Keep a map of which fields are on which lines, (to save scanning through the list again)
					self.fields[line[0:line.index('=')]] = i
				i += 1

	def set(self, key: str, value: str):
		if key in self.fields:
			self.lines[self.fields[key]] = f'{key}={value}\n'
		else:
			self.lines.append(f'{key}={value}\n')
			self.fields[key] = len(self.lines) - 1

	def save(self):
		with open(self.filename, 'w') as f:
			f.writelines(self.lines)


def run():

	# Setup repo
	os_name = operating_system.get_name()
	upstream_id = operating_system.get_upstream_id()
	upstream_version = operating_system.get_upstream_version_major()
	base_dir = '/opt/tacticalagent'
	role = os.environ.get('ROLE', 'agent')
	server = os.environ.get('SERVER', None)
	hostname = os.environ.get('HOSTNAME', None)

	if server is None or hostname is None:
		usage()

	# @todo support arm64
	# os_arch = operating_system.get_arch()

	# Disable Zabbix packages provided by EPEL
	if os.path.exists('/etc/yum.repos.d/epel.repo'):
		yum_repo = YumRepos('epel')
		if yum_repo.has_repo('epel'):
			yum_repo.get_repo('epel').add_excluded_package('zabbix*')
			yum_repo.save()

	# Determine the source URL, (different systems will have different installers)
	if upstream_id == 'debian' and 10 <= upstream_version <= 12:
		source = f'https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian{upstream_version}_all.deb'
		installer = 'dpkg'
	elif upstream_id == 'ubuntu' and 18 <= upstream_version <= 24:
		source = f'https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu{upstream_version}.04_all.deb'
		installer = 'dpkg'
	elif os_name == 'Rocky Linux' and 8 <= upstream_version <= 9:
		source = f'https://repo.zabbix.com/zabbix/7.0/rocky/{upstream_version}/x86_64/zabbix-release-7.0-5.el{upstream_version}.noarch.rpm'
		installer = 'rpm'
	else:
		print('Unsupported operating system')
		sys.exit(1)

	# Download the repo installer if necessary
	repo_base_file = os.path.basename(source)
	repo_file = os.path.join(base_dir, 'temp', repo_base_file)
	if not os.path.exists(repo_file):
		urlretrieve(source, repo_file)

	# Install the repo
	if installer == 'dpkg':
		DpkgInstall().install_file(repo_file)
	elif installer == 'rpm':
		RpmInstall().install_file(repo_file)

	# Install and configure the requested package(s)
	if role == 'proxy':
		if installer == 'dpkg':
			AptInstall().install_packages(['zabbix-proxy-sqlite3'])
		elif installer == 'rpm':
			YumInstall().install_packages(['zabbix-proxy-sqlite3', 'zabbix-selinux-policy'])

		zabbix_conf = ZabbixConfig('/etc/zabbix/zabbix_proxy.conf')
		zabbix_conf.set('Server', server)
		zabbix_conf.set('Hostname', hostname)
		zabbix_conf.set('EnableRemoteCommands', '1')
		zabbix_conf.set('AllowUnsupportedDBVersions', '1')
		zabbix_conf.set('DBName', '/var/lib/zabbix/zabbix_proxy.db')
		zabbix_conf.save()

		if not os.path.exists('/var/lib/zabbix'):
			os.mkdir('/var/lib/zabbix')

		os.chown('/var/lib/zabbix', pwd.getpwnam('zabbix').pw_uid, grp.getgrnam('zabbix').gr_gid)

		service = SystemCtlService('zabbix-proxy')
		service.enable()
		service.restart()

		print('')
		print('=====================================================')
		print(f'If you have not done so already, create a new Proxy in {server}')
		print(f'for hostname {hostname}')
		print('(Administration -> Proxies -> Create proxy)')
		print('')
		print('Followed by setting its IP range and checks enabled')
		print('(Data collection -> Discovery')
	elif role == 'agent':
		if installer == 'dpkg':
			AptInstall().install_packages(['zabbix-agent2', 'zabbix-agent2-plugin-*'])
		elif installer == 'rpm':
			YumInstall().install_packages(['zabbix-agent2', 'zabbix-agent2-plugin-*'])

		zabbix_conf = ZabbixConfig('/etc/zabbix/zabbix_agent2.conf')
		zabbix_conf.set('Server', server)
		zabbix_conf.set('ServerActive', server)
		zabbix_conf.set('Hostname', hostname)
		zabbix_conf.save()

		service = SystemCtlService('zabbix-agent2')
		service.enable()
		service.restart()

		print('')
		print('=====================================================')
		print(f'If you have not done so already, create a new Host in {server}')
		print(f'for hostname {hostname}')
	else:
		usage()


if __name__ == '__main__':
	run()
