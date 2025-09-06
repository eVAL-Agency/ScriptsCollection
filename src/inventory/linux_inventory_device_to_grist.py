#!/usr/bin/env python3
"""
Collect Asset Inventory (Grist) [Linux]

Collect asset information for a device including CPU, memory, network, and OS details.
This information is then sent to Grist for asset tracking.

TRMM Environment:
	GRIST_URL={{client.grist_url}}
	GRIST_ACCOUNT={{client.grist_account}}

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

Changelog:
	20250906 - Switch script from SuiteCRM to Grist
	20250205 - Fix debug statement on CPU lookup
	20240130 - Switch to standardized cmd library
		Add support for "test" for CRM url (useful for debugging)
	20240128 - Add support for Raspberry PI devices
		Print URL for created/updated device
		Switch from single-device ID assigning to lookup via MAC to simplify deployment
		Switch to standardized suitecrmsync library
		Add board_model lookup
	20240111 - Initial release
"""


import os
import logging
import argparse
import sys
from urllib import request

from typing import Union

from scriptlets._common.cmd import *


parser = argparse.ArgumentParser(
	prog='linux_inventory_device_to_grist.py',
	description='Collect device asset inventory and send to Grist')

parser.add_argument('--debug', action='store_true', help='Enable debug output')

options = parser.parse_args()

crm_url = os.getenv('GRIST_URL')
crm_client_id = os.getenv('GRIST_ACCOUNT')

if options.debug:
	logging.basicConfig(level=logging.DEBUG)

if crm_url is None:
	print('GRIST_URL is not set', file=sys.stderr)
	sys.exit(1)

if crm_client_id is None:
	print('GRIST_ACCOUNT is not set', file=sys.stderr)
	sys.exit(1)

# scriptlet:_common/require_root.py

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
	if value is not None:
		data[key] = value

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

if cpu_model is None:
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
		mem_type = ("%s %s" % (mem_type, mem_form_factor))

		# The memory is ECC if its total width is different from the data width;
		# (the extra bits are the error correction bits).
		if mem_total_width is not None and mem_data_width is not None and mem_total_width != mem_data_width:
			mem_type = "%s (ECC)" % mem_type

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
	print('Skipping Grist sync, CRM_URL is set to test', file=sys.stderr)
	exit(0)

# Send this data to the Grist middleware application and let it figure everything out
headers = {
	'Content-Type': 'application/json',
	'X-Token': crm_client_id,
}

req = request.Request(
	crm_url + '/scripts/device_inventory',
	method='POST',
	headers=headers,
	data=json.dumps(data).encode('utf-8')
)
request.urlopen(req)
