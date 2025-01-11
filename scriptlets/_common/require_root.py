##
# Simple check to enforce the script to be run as root
import os
import ctypes

try:
	if os.getuid() != 0:
		print("This script must be run as root!")
		exit(1)
except AttributeError:
	# Windows doesn't have os.getuid
	if not ctypes.windll.shell32.IsUserAnAdmin():
		print("This script must be run with administrative privileges!")
		exit(1)
