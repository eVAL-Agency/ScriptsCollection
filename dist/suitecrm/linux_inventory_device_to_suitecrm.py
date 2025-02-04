#!/usr/bin/env python3
"""
Collect Asset Inventory (SuiteCRM) [Linux]

Collect asset information for a device including CPU, memory, network, and OS details.
This information is then sent to SuiteCRM for asset tracking.

TRMM Environment:
	CRM_URL={{client.crm_url}}
	CRM_CLIENT_ID={{client.crm_client_id}}
	CRM_CLIENT_SECRET={{client.crm_client_secret}}

Syntax:
	--debug: Enable debug logging

Supports:
	Linux-All

Category:
	Asset Tracking

License:
	AGPLv3

Author:
	Charlie Powell <cdp1337@veraciousnetwork.com>
"""
import os
import logging
import argparse
import sys
import json
from typing import Union
import time
from urllib import request
from urllib.error import HTTPError
from urllib import parse as urlparse
import subprocess
import ctypes

"""
SuiteCRM Sync Library

Provides a simple API to interface with SuiteCRM via the REST API.
Built against SuiteCRM 7.14.5, probably does not work with v8
(mostly because SuiteCRM v8 is unfinished and at the time of writing, kinda sucks)

Features:

* OAuth2 authentication (only support auth mechanism)
* Create records (POST to /Api/V8/module)
* Update records (PATCH to /Api/V8/module)
* Find records (GET to /Api/V8/module/[MODULE_NAME])

License:
	AGPLv3

Version:
	2025.01.28

Changelog:
	2025.01.28
		* Added debug logging
		* Create and update return server data
"""


class SuiteCRMSyncException(Exception):
	pass


class SuiteCRMSyncAuthException(SuiteCRMSyncException):
	pass


class SuiteCRMSyncDataException(SuiteCRMSyncException):
	pass


class SuiteCRMSyncResponseException(SuiteCRMSyncException):
	pass


class SuiteCRMSync:
	"""
	Simple API to interface with SuiteCRM
	"""

	def __init__(self, url: str, client_id: str, client_secret: str):
		self.token = None
		self.expires = 0
		self.url = url
		self.client_id = client_id
		self.client_secret = client_secret

	def _send(
		self,
		url: str,
		method: str,
		data: Union[dict, None] = None,
		auth: bool = True,
		sensitive: tuple = ()
	):
		headers = {
			'Content-Type': 'application/json',
			'Accept': 'application/json',
		}
		if auth:
			headers['Authorization'] = 'Bearer %s' % self.get_token()

		log_url = self.url + url
		url = 'https://' + self.url + url
		log_data = dict(data) if data is not None else None

		if method.upper() == 'GET':
			post_data = None
			if data is not None:
				url += ('&' if '?' in url else '?') + urlparse.urlencode(data)
		else:
			post_data = data

		if post_data is not None:
			for key in sensitive:
				if key in log_data:
					log_data[key] = log_data[key][0:4] + '********'
			logging.debug('[suitecrmsync] Sending payload via %s to %s\n%s' % (method, log_url, json.dumps(log_data)))
			req = request.Request(
				url,
				method=method,
				headers=headers,
				data=json.dumps(post_data).encode('utf-8')
			)
		else:
			logging.debug('[suitecrmsync] Sending request via %s to %s' % (method, log_url))
			req = request.Request(
				url,
				method=method,
				headers=headers
			)

		response = ''
		try:
			ret = request.urlopen(req)
			response = ret.read()
			response_data = json.loads(response)
			logging.debug('[suitecrmsync] Request completed successfully\n%s' % response)
			return response_data
		except HTTPError as e:
			response = e.read()
			logging.error('[suitecrmsync] Request failed\n%s' % response)
			raise SuiteCRMSyncException()
		except json.decoder.JSONDecodeError:
			logging.error('[suitecrmsync] Failed to parse response\n%s' % response)
			raise SuiteCRMSyncException()

	def get_token(self) -> str:
		"""
		Get an access token from SuiteCRM based on OAuth2 client_id and client_secret

		Called automatically when required
		:return:
		"""
		if self.expires < int(time.time()):
			logging.debug('[suitecrmsync] Token expired or not set yet, obtaining new token')
			# Request an access token via OAuth2 from SuitCRM
			try:
				data = self._send(
					'/Api/access_token',
					'POST',
					{
						'grant_type': 'client_credentials',
						'client_id': self.client_id,
						'client_secret': self.client_secret,
					},
					False,
					('client_secret',)
				)
				self.token = data['access_token']
				self.expires = int(time.time()) + data['expires_in'] - 60
			except SuiteCRMSyncException:
				raise SuiteCRMSyncResponseException(
					'Failed to get access token, please check the credentials and server connectivity'
				)
		return self.token

	def update(self, object_type: str, object_id: str, data: dict):
		"""
		Patch/update a record in SuiteCRM

		:param object_type:
		:param object_id:
		:param data:
		:return
		"""

		# Send the UPDATE request to SuiteCRM
		try:
			return self._send(
				'/Api/V8/module',
				'PATCH',
				{
					'data': {
						'type': object_type,
						'id': object_id,
						'attributes': data,
					}
				}
			)
		except SuiteCRMSyncException:
			raise SuiteCRMSyncDataException('Failed to update %s %s\n%s' % (object_type, object_id, json.dumps(data)))

	def create(self, object_type: str, data: dict):
		"""
		create a record in SuiteCRM
		:param object_type:
		:param data:
		:return
		"""

		# Send the device data to SuiteCRM
		try:
			return self._send(
				'/Api/V8/module',
				'POST',
				{
					'data': {
						'type': object_type,
						'attributes': data,
					}
				}
			)
		except SuiteCRMSyncException:
			raise SuiteCRMSyncDataException('Failed to create %s\n%s' % (object_type, json.dumps(data)))

	def find(self, object_type: str, filters: dict, operator: str = 'AND', fields: [str] = ('id',)):
		"""

		:param object_type:
		:param filters:
		:param operator:
		:param fields:
		:return:
		"""
		params = {
			'fields[' + object_type + ']': ','.join(fields),
			'filter[operator]': operator,
		}
		op_map = {
			'=': 'EQ',
			'==': 'EQ',
			'!=': 'NEQ',
			'<>': 'NEQ',
			'>': 'GT',
			'>=': 'GTE',
			'<': 'LT',
			'<=': 'LTE',
		}
		for f_key in filters.keys():
			f_val = filters[f_key]
			if isinstance(f_val, list) or isinstance(f_val, tuple):
				f_op = f_val[0]
				f_val = f_val[1]
			else:
				f_op = 'EQ'

			if f_op.upper() in ('EQ', 'NEQ', 'GT', 'GTE', 'LT', 'LTE'):
				# Supported value; no modification required
				pass
			elif f_op in op_map:
				f_op = op_map[f_op]
			else:
				raise SuiteCRMSyncDataException(
					('Invalid filter format: %s %s %s' % (f_key, f_op, f_val))
				)

			params['filter[' + f_key + '][' + f_op + ']'] = f_val

		try:
			data = self._send(
				'/Api/V8/module/%s' % object_type,
				'GET',
				params
			)
			ret = []
			for record in data['data']:
				if len(record['attributes']) == 0:
					ret.append({'id': record['id']})
				else:
					ret.append(record['attributes'] | {'id': record['id']})
			return ret
		except SuiteCRMSyncException:
			raise SuiteCRMSyncDataException('Failed to find %s\n%s' % (object_type, json.dumps(params)))

class Cmd:
	"""
	Simple subprocess wrapper to provide convenience methods for common interactions.
	"""
	def __init__(self, cmd: list):
		self.cmd = cmd
		self.result = None

	def exists(self) -> bool:
		"""
		Check if this binary exists
		:return:
		"""
		return subprocess.run(['which', self.cmd[0]], check=False, stdout=subprocess.PIPE).returncode == 0

	def text(self) -> str:
		"""
		Get the output of the command as raw text
		:return:
		"""
		return self._exec().stdout.strip()

	def lines(self) -> list:
		"""
		Get the output of the command as lines of text (as a list)
		:return:
		"""
		return self.text().split('\n')

	def json(self):
		"""
		Get the output of the command decoded as JSON
		:return:
		"""
		return json.loads(self.text())

	def _exec(self):
		if self.result is None:
			self.result = subprocess.run(
				self.cmd,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				check=True,
				encoding='utf-8'
			)

		return self.result


parser = argparse.ArgumentParser(
	prog='linux_inventory_device_to_suitecrm.py',
	description='Collect device asset inventory and send to SuiteCRM')

parser.add_argument('--debug', action='store_true', help='Enable debug output')

options = parser.parse_args()

crm_url = os.getenv('CRM_URL')
crm_client_id = os.getenv('CRM_CLIENT_ID')
crm_client_secret = os.getenv('CRM_CLIENT_SECRET')
crm_object = 'MSP_Devices'

if options.debug:
	logging.basicConfig(level=logging.DEBUG)

if crm_url is None:
	print('CRM_URL is not set', file=sys.stderr)
	sys.exit(1)

if crm_client_id is None:
	print('CRM_CLIENT_ID is not set', file=sys.stderr)
	sys.exit(1)

if crm_client_secret is None:
	print('CRM_CLIENT_SECRET is not set', file=sys.stderr)
	sys.exit(1)

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

empty_values = (
	'',
	'0123456789',
	'Default string',
	'N/A',
	'None',
	'No Asset Tag',
	'Not Applicable',
	'Not Specified',
	'System Product Name',
	'System Serial Number',
	'System Version',
	'System manufacturer',
	'Tag 12345',
	'To Be Filled By O.E.M.',
	'Unknown'
)
'''
Any value which should be parsed as empty
'''

field_map = {
	'hostname': 'name',
	'manufacturer': 'manufacturer',
	'model': 'model',
	'serial': 'serial',
	'os_name': 'os_name',
	'os_version': 'os_version',
	'cpu_model': 'cpu_model',
	'cpu_threads': 'cpu_threads',
	'mem_type': 'mem_type',
	'mem_speed': 'mem_speed',
	'mem_size': 'mem_size',
	'mem_model': 'mem_model',
	'ip_primary': 'ip_pri',
	'mac_primary': 'mac_pri',
	'ip_secondary': 'ip_sec',
	'mac_secondary': 'mac_sec',
	'board_manufacturer': 'board_manufacturer',
	'board_serial': 'board_serial',
	'board_model': 'board_model',
	'hardware_version': 'hardware_version',
}
'''
Map of fields to their corresponding SuiteCRM field names
'''

def read_from(sources: list) -> Union[str, None]:
	for source in sources:
		try:
			with open(source, 'r') as f:
				val = f.read().strip()
				if val not in empty_values:
					return val
		except Exception:
			pass

	return None

def set_field(key: str, value: Union[str, None]):
	if value is not None and key in field_map:
		data[field_map[key]] = value

data = {}


# Grab hostname from binary
set_field('hostname', Cmd(['hostname', '-f']).text())


# Read general hardware info basic files as provided from the kernel
set_field('manufacturer', read_from(['/sys/devices/virtual/dmi/id/chassis_vendor']))
set_field('model', read_from(['/sys/devices/virtual/dmi/id/product_name']))
set_field('serial', read_from([
	'/sys/devices/virtual/dmi/id/product_serial',
	'/sys/devices/virtual/dmi/id/chassis_serial'
]))
set_field('hardware_version', read_from([
	'/sys/devices/virtual/dmi/id/product_version',
	'/sys/devices/virtual/dmi/id/chassis_version'
]))
set_field('board_manufacturer', read_from(['/sys/devices/virtual/dmi/id/board_vendor']))
set_field('board_model', read_from(['/sys/devices/virtual/dmi/id/board_name']))
set_field('board_serial', read_from(['/sys/devices/virtual/dmi/id/board_serial']))


# Read processor information from /proc/cpuinfo
cpu_model = None
cpu_threads = 0
cpu_sockets = []
with open('/proc/cpuinfo', 'r') as f:
	for line in f:
		if line.startswith('model name'):
			cpu_model = line.split(':')[1].strip()
		elif line.startswith('processor'):
			cpu_threads += 1
		elif line.startswith('physical id'):
			if line not in cpu_sockets:
				cpu_sockets.append(line)
		elif line.startswith('Serial'):
			# Raspberry PI has their hardware information in /proc/cpuinfo
			set_field('board_serial', line.split(':')[1].strip())
		elif line.startswith('Model'):
			# Raspberry PI has their hardware information in /proc/cpuinfo
			val = line.split(':')[1].strip()
			set_field('board_model', val)
			if 'Raspberry Pi' in val:
				set_field('board_manufacturer', 'Raspberry Pi Ltd')

if cpu_model is None or True:
	# Try lscpu instead
	cpu_data = Cmd(['lscpu', '-J']).json()
	for record in cpu_data['lscpu']:
		if record['field'] == 'Model name:':
			cpu_model = record['data']


if len(cpu_sockets) > 1 and cpu_model is not None:
	set_field('cpu_model', "%sx %s" % (len(cpu_sockets), cpu_model))
else:
	set_field('cpu_model', cpu_model)

if cpu_threads > 0:
	set_field('cpu_threads', cpu_threads)


# Read memory information from /proc/meminfo or dmidecode if available
dmi = Cmd(['dmidecode', '--type', 'memory'])
if dmi.exists():
	# Use dmidecode to gather memory information, (if it's installed)
	# Just because this is present does not mean it'll succeed though,
	# Raspberry PIs do not support SMBIOS information, so nothing will be returned
	# and we'll need to fallback to /proc/meminfo
	memory = []
	current_stick = None
	for line in dmi.lines():
		if line.startswith('Memory Device'):
			current_stick = {
				'total_width': None,
				'data_width': None,
				'size': None,
				'form_factor': None,
				'type': None,
				'speed': None,
				'part': None,
			}
		elif line == '' and current_stick is not None:
			memory.append(current_stick)
			current_stick = None
		elif current_stick and line.startswith('\tTotal Width:'):
			current_stick['total_width'] = line.split(':')[1].strip()
		elif current_stick and line.startswith('\tData Width:'):
			current_stick['data_width'] = line.split(':')[1].strip()
		elif current_stick and line.startswith('\tType:'):
			current_stick['type'] = line.split(':')[1].strip()
		elif current_stick and line.startswith('\tSpeed:') and line.strip().endswith(' MT/s'):
			current_stick['speed'] = line.split(':')[1].strip()[:-5]
		elif current_stick and line.startswith('\tForm Factor:'):
			current_stick['form_factor'] = line.split(':')[1].strip()
		elif current_stick and line.startswith('\tSize:') and 'No Module Installed' not in line:
			current_stick['size'] = line.split(':')[1].strip()
		elif current_stick and line.startswith('\tPart Number:'):
			current_stick['part'] = line.split(':')[1].strip()

	if current_stick is not None:
		# Last stick (the output would have been completed)
		memory.append(current_stick)
		current_stick = None

	# memory now contains a list of all memory sticks, each with the necessary information for each module
	mem_total_width = None
	mem_data_width = None
	mem_type = None
	mem_speed = None
	mem_size = 0
	mem_form_factor = None
	mem_sticks = {}
	for stick in memory:
		if stick['size'] is None:
			l = 'Empty'
		else:
			l = "%s %s" % (stick['size'], stick['part'])
			mem_total_width = stick['total_width']
			mem_data_width = stick['data_width']
			mem_type = stick['type']
			mem_speed = stick['speed']
			mem_form_factor = stick['form_factor']
			mem_size += int(stick['size'].split(' ')[0])

		if l not in mem_sticks:
			mem_sticks[l] = 1
		else:
			mem_sticks[l] += 1

	if mem_type is not None and mem_form_factor is not None:
		mem_type = ("%s_%s" % (mem_type, mem_form_factor)).lower()

		# The memory is ECC if its total width is different from the data width;
		# (the extra bits are the error correction bits).
		if mem_total_width is not None and mem_data_width is not None and mem_total_width != mem_data_width:
			mem_type = "%s_ecc" % mem_type

		set_field('mem_type', mem_type)

	set_field('mem_speed', mem_speed)
	set_field('mem_size', mem_size)

	mem_models = []
	for type in mem_sticks:
		mem_models.append("%sx %s" % (mem_sticks[type], type))

	set_field('mem_model', ', '.join(mem_models))

if 'mem_size' not in data or data['mem_size'] == 0:
	# Lookup from dmidecode failed, fallback to /proc/meminfo
	with open('/proc/meminfo', 'r') as f:
		for line in f:
			if line.startswith('MemTotal:'):
				mem_size = line.split(':')[1].strip()
				if mem_size.endswith(' kB'):
					mem_size = int(round(int(mem_size[:-3]) / 1024 / 1024, 0))
				set_field('mem_size', mem_size)


# Get OS name and version from common, (and not-so-common) sources
pve = Cmd(['pveversion'])
if pve.exists():
	set_field('os_name', 'Proxmox')
	set_field('os_version', pve.text().split('/')[1])
elif os.path.exists('/etc/os-release'):
	with open('/etc/os-release', 'r') as f:
		for line in f:
			if line.startswith('NAME='):
				set_field('os_name', line.split('=')[1].strip().strip('"'))
			elif line.startswith('VERSION='):
				set_field('os_version', line.split('=')[1].strip().strip('"'))


# Get IP and MAC address for this device
ifaces = Cmd(['ip', '-j', 'address']).json()
pri_sent = False
for iface in ifaces:
	if iface['operstate'] == 'DOWN':
		continue

	if 'LOOPBACK' in iface['flags']:
		# Skip loopback interfaces
		continue

	if 'POINTOPOINT' in iface['flags']:
		# Skip VPNs
		continue

	if len(iface['addr_info']) == 0:
		# Skip interfaces with no IP set
		continue

	if not pri_sent:
		pri_sent = True
		set_field('ip_primary', iface['addr_info'][0]['local'])
		set_field('mac_primary', iface['address'])
	else:
		set_field('ip_secondary', iface['addr_info'][0]['local'])
		set_field('mac_secondary', iface['address'])
		break

print(json.dumps(data, indent=4))

if crm_url == 'test':
	print('Skipping SuiteCRM sync, CRM_URL is set to test', file=sys.stderr)
	exit(0)

# Request an access token via OAuth2 from SuitCRM
sync = SuiteCRMSync(crm_url, crm_client_id, crm_client_secret)
sync.get_token()

# Lookup the device based on its MAC
if field_map['mac_primary'] in data:
	mac = data[field_map['mac_primary']]
	ret = sync.find(
		'MSP_Devices',
		{'mac_pri': mac, 'mac_sec': mac},
		operator='OR',
		fields=('id',)
	)
else:
	print('Unable to sync to SuiteCRM, no MAC found', file=sys.stderr)
	exit(1)

if len(ret) == 0:
	# New device
	ret = sync.create('MSP_Devices', data)
	print(
		'Updated device record https://' +
		crm_url +
		'/index.php?action=ajaxui#ajaxUILoc=index.php%3Fmodule%3DMSP_Devices%26action%3DDetailView%26record%3D' +
		ret['data']['id'], file=sys.stderr
	)

else:
	# Update existing device
	sync.update('MSP_Devices', ret[0]['id'], data)
	print(
		'Updated device record https://' +
		crm_url +
		'/index.php?action=ajaxui#ajaxUILoc=index.php%3Fmodule%3DMSP_Devices%26action%3DDetailView%26record%3D' +
		ret[0]['id'], file=sys.stderr
	)
