#!/usr/bin/env python3
"""
Check Disk Space [Linux]

Check disk space and report an error if usage is above threshold.
Supports traditional partitions and ZFS pools.

TRMM ARGUMENTS:
	--threshold 20

Syntax:
	--threshold: <int> - The percentage of free space that is considered a warning

Supports:
	Linux-All

Category:
	Disks

License:
	AGPLv3

Author:
	Charlie Powell <cdp1337@veraciousnetwork.com>

Changelog:
	20250204 - Add mount point to output
	20250130 - Initial version
"""
import argparse
import subprocess
import json

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


parser = argparse.ArgumentParser(description="Check Disk Space [Linux]")
parser.add_argument(
	"--threshold",
	type=int,
	default=20,
	help="The percentage of free space that is considered a warning"
)
options = parser.parse_args()

ret = 0
for line in Cmd(['df', '--output=source,pcent,target']).lines():
	if not line.startswith('/dev/'):
		# Only check physical partitions
		continue

	if '/loop' in line:
		# Skip loop devices
		continue

	line_parts = line.split()

	free = 100 - int(line_parts[1][:-1])
	if free < options.threshold:
		print('WARNING: Partition %s (%s) has %s%% free space remaining!' % (line_parts[0], line_parts[2], free))
		ret = 1
	else:
		print('Partition %s (%s) has %s%% free space remaining.' % (line_parts[0], line_parts[2], free))

# Check ZFS pools
zfs = Cmd(['zpool', 'list', '-H', '-o', 'name,capacity'])
if zfs.exists():
	for line in zfs.lines():
		free = 100 - int(line.split()[1][:-1])
		if free < options.threshold:
			print('WARNING: ZFS pool %s has %s%% free space remaining!' % (line.split()[0], free))
			ret = 1
		else:
			print('ZFS pool %s has %s%% free space remaining.' % (line.split()[0], free))

exit(ret)
