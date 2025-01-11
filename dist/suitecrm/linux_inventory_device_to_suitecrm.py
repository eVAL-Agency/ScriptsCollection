#!/usr/bin/env python3
"""
Collect Asset Inventory (SuiteCRM)

Collect asset information for a device including CPU, memory, network, and OS details.
This information is then sent to SuiteCRM for asset tracking.

TRMM Environment:
    CRM_URL={{client.crm_url}}
    CRM_CLIENT_ID={{client.crm_client_id}}
    CRM_CLIENT_SECRET={{client.crm_client_secret}}
    CRM_ID={{agent.crm_id}}

Supports:
    Linux-All

Category:
    Asset Tracking
import os
import subprocess
import json
import sys
import ctypes"""


from typing import Union
from urllib import request
from urllib.error import HTTPError

crm_url = os.getenv('CRM_URL')
crm_client_id = os.getenv('CRM_CLIENT_ID')
crm_client_secret = os.getenv('CRM_CLIENT_SECRET')
crm_id = os.getenv('CRM_ID')
crm_object = 'MSP_Devices'

if crm_url is None:
	print('CRM_URL is not set', file=sys.stderr)
	sys.exit(1)

if crm_client_id is None:
	print('CRM_CLIENT_ID is not set', file=sys.stderr)
	sys.exit(1)

if crm_client_secret is None:
	print('CRM_CLIENT_SECRET is not set', file=sys.stderr)
	sys.exit(1)

if crm_id is None:
	print('CRM_ID is not set', file=sys.stderr)
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
process = subprocess.run(['hostname', '-f'], stdout=subprocess.PIPE)
set_field('hostname', process.stdout.decode().strip())


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
set_field('board_serial', read_from(['/sys/devices/virtual/dmi/id/board_serial']))


# Read processor information from /proc/cpuinfo
cpu_model = None
cpu_threads = 0
cpu_sockets = []
with open('/proc/cpuinfo', 'r') as f:
	for line in f:
		if line.startswith('model name'):
			cpu_model = line.split(':')[1].strip()
			cpu_threads += 1
		elif line.startswith('physical id'):
			if line not in cpu_sockets:
				cpu_sockets.append(line)

if len(cpu_sockets) > 1 and cpu_model is not None:
	set_field('cpu_model', "%sx %s" % (len(cpu_sockets), cpu_model))
else:
	set_field('cpu_model', cpu_model)

if cpu_threads > 0:
	set_field('cpu_threads', cpu_threads)


# Read memory information from /proc/meminfo or dmidecode if available
if subprocess.run(['which', 'dmidecode'], check=False, stdout=subprocess.PIPE).returncode != 0:
	print('dmidecode not found, unable to provide full details for memory', file=sys.stderr)

	with open('/proc/meminfo', 'r') as f:
		for line in f:
			if line.startswith('MemTotal:'):
				mem_size = line.split(':')[1].strip()
				if mem_size.endswith(' kB'):
					mem_size = int(round(int(mem_size[:-3]) / 1024 / 1024, 0))
				set_field('mem_size', mem_size)
else:
	memory = []
	current_stick = None
	process = subprocess.run(['dmidecode', '--type', 'memory'], stdout=subprocess.PIPE)
	for line in process.stdout.decode().split('\n'):
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


# Get OS name and version from common, (and not-so-common) sources
if subprocess.run(['which', 'pveversion'], check=False, stdout=subprocess.PIPE).returncode == 0:
	set_field('os_name', 'Proxmox')
	process = subprocess.run(['pveversion'], stdout=subprocess.PIPE)
	set_field('os_version', process.stdout.decode().strip().split('/')[1])
elif os.path.exists('/etc/os-release'):
	with open('/etc/os-release', 'r') as f:
		for line in f:
			if line.startswith('NAME='):
				set_field('os_name', line.split('=')[1].strip().strip('"'))
			elif line.startswith('VERSION='):
				set_field('os_version', line.split('=')[1].strip().strip('"'))


# Get IP and MAC address for this device
process = subprocess.run(['ip', '-j', 'address'], stdout=subprocess.PIPE)
ifaces = json.loads(process.stdout.decode().strip())
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

# Request an access token via OAuth2 from SuitCRM
req = request.Request(
	'https://%s/Api/access_token' % crm_url,
	method='POST',
	headers={
		'Content-Type': 'application/json',
		'Accept': 'application/json',
	},
	data=json.dumps({
		'grant_type': 'client_credentials',
		'client_id': crm_client_id,
		'client_secret': crm_client_secret,
	}).encode('utf-8')
)
try:
	ret = request.urlopen(req)
except HTTPError as e:
	print('Failed to get access token, please check the credentials and server connectivity', file=sys.stderr)
	print(e.read(), file=sys.stderr)
	sys.exit(1)

try:
	token = json.loads(ret.read())['access_token']
except json.decoder.JSONDecodeError:
	print('Failed to parse access token response', file=sys.stderr)
	print(ret.read(), file=sys.stderr)
	sys.exit(1)

# Send the device data to SuiteCRM
req = request.Request(
	'https://%s/Api/V8/module' % crm_url,
	method='PATCH',
	headers={
		'Content-Type': 'application/json',
		'Accept': 'application/json',
		'Authorization': 'Bearer %s' % token,
	},
	data=json.dumps({
		'data': {
			'type': crm_object,
			'id': crm_id,
			'attributes': data,
		}
	}).encode('utf-8')
)

try:
	request.urlopen(req)
except HTTPError as e:
	print('Failed to send device info to SuiteCRM', file=sys.stderr)
	print(e.read(), file=sys.stderr)
	sys.exit(1)
