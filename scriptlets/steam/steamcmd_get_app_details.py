import subprocess
import os
import sys
from typing import Union
from scriptlets.steam.steamcmd_parse_manifest import *


def steamcmd_get_app_details(app_id: str, steamcmd_path: str = None) -> Union[dict, None]:
	"""
	Get detailed information about a Steam app using steamcmd

	Returns a dictionary with:

	- common
		- name
		- type
		- parent
		- ReleaseState
		- oslist
		- osarch
		- osextended
		- icon
		- clienticon
		- clienttga
		- freetodownload
		- associations
		- gameid
	- extended
		- gamedir
	- config
		- installdir
		- launch
		- uselaunchcommandline
	- depots

	:param app_id:
	:param steamcmd_path:
	:return:
	"""
	if steamcmd_path is None:
		# Try to find steamcmd in the common locations
		paths = ("/usr/games/steamcmd", "/usr/local/games/steamcmd", "/opt/steamcmd/steamcmd.sh")
		for path in paths:
			if os.path.exists(path):
				steamcmd_path = path
				break
		else:
			print('steamcmd not found in common locations. Please provide the path to steamcmd.', file=sys.stderr)
			return None

	# Construct the command to get app details
	command = [
		steamcmd_path,
		"+login", "anonymous",
		"+app_info_update", "1",
		"+app_info_print", str(app_id),
		"+quit"
	]

	try:
		# Run the steamcmd command
		result = subprocess.run(command, capture_output=True, text=True, check=True)

		# Output from command should be Steam manifest format, parse it
		dat = steamcmd_parse_manifest(result.stdout)
		if app_id in dat:
			return dat[app_id]
		else:
			print(f"App ID {app_id} not found in steamcmd output.", file=sys.stderr)
			return None

	except subprocess.CalledProcessError as e:
		print(f"Error running steamcmd: {e}")
		return None
