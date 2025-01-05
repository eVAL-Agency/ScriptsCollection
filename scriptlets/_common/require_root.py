##
# Simple check to enforce the script to be run as root
import os
if os.getuid() != 0:
	print("This script must be run as root!")
	exit(1)
