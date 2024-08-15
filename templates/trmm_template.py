#!/opt/tacticalagent/toolbox/some-tool-name/bin/python3
"""
Some description of this script, what it does, and how it works.

Supports:
	List of operating systems this script supports and their versions
	Feel free to adjust as necessary, no strict format requirements,
	just should be useful to the end sysadmin.
	Alma Linux n - n
	CentOS n - n
	Debian n - n
	Fedora n - n
	FreeBSD n - n
	MacOS n - n
	OpenSuSE n - n
	Rocky Linux n - n
	SLES n - n
	Ubuntu n - n
	Windows n - n
	Windows Server n - n

Requirements:
	None | List of requirements / dependencies

TRMM Custom Fields:
	None | List of custom fields that should be present in TRMM
	client.some_client_level_field - Some field that should be set at the client level
	site.some_site_level_field - Some field that should be set at the site level
	agent.some_agent_level_field - Some field that should be set at the agent level

Args:
	None | List of arguments that can be passed to the script

Environment Variables:
	None | List of environment variables that can be set to adjust the behavior of the script

License:
	name-of-your-license-here

Author:
	Your name, email, and/or contact info

Changelog:
	YYYY.MM.DD - Original Release
	or whatever format you would like to use for indicating changes throughout the life of the script.
"""

import sys


def usage():
	print('Usage: my-script.py -some-arg [-some-optional-arg]')
	print('')
	print('Environmental Variables:')
	print('  Are there any env vars that are expected?')
	sys.exit(1)


def run():
	"""
	Run the script
	:return:
	"""

	'''
	Your script code here
	
	
	If you need an environmental variable:
	
	```python
	my_var = os.environ.get('NAME_OF_VAR', 'default-value-if-not-set')
	```
	
	
	Bad variables provided: display usage and exit
	
	```python
	if some_expectations_not_met:
		usage()
	
	
	Need to download an installer file?
	
	```python
	from urllib.request import urlretrieve
	import os
	
	source_url = 'https://some-url.com/some-installer.sh'
	source_base_filename = os.path.basename(source_url)
	source_file = os.path.join('/opt/tacticalagent/temp', source_base_filename)
	if not os.path.exists(source_file):
		urlretrieve(source_url, source_file)
	```
	'''

	print('')
	print('=====================================================')
	print('Any information to be presented to the tech who runs this script')
	print('obviously do not do this for data collection scripts, as this will print to stdout')

	print('Informational messages can instead be sent over stderr', file=sys.stderr)
	print('if you need to preserve the output for the output of your script', file=sys.stderr)


if __name__ == '__main__':
	run()
