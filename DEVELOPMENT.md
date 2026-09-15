# Scripts Collection Development

This describes how to work within this collection to compile deployment-ready scripts.

## Testing Scripts

### Linux

* Copy the script from `dist/` to the test environment and run it.

### Windows

* Open start menu
* Search for "Powershell"
* Right-click and select "Run as Administrator"
* Navigate to `dist/` and run the script
* Run command: `Set-ExecutionPolicy -ExecutionPolicy ByPass -Scope LocalMachine`
* Copy the script from `dist/` to the test environment and run it as Administrator.

## Project Structure

```
ScriptsCollection
├── .supplemental/
│    ├── images/             # Icons used in README
│    └── README-template.md  # Template for README.md
├── dist/                    # Compiled scripts ready for deployment
├── scriptlets/              # Shared snippet functionality
└── src/                     # Source scripts
```

Source scripts reside within `src/` and should be grouped with the application
they are related to.

Shared snippet functionality is stored in `scriptlets/` and can be included within
scripts via `# scriptlet:path/to/scriptlet.ext`.

Running the compiler will combine all snippets for all scripts into a single file within `dist/`.


## Compile all scripts

Compiling scripts combines all snippet depdendencies into a single file for easy deployment of the requested script.

This is done by running the compile script with Python.
This will iterate over each script in `src/` and compile production-ready versions in `dist/`.

```bash
python3 compile.py

# or just directly if chmod +x
./compile.py
```

## Writing Scripts

### Script Metadata

Metadata about scripts are stored in the header of the script.
This metadata includes:

* Title
* Syntax
* Arguments
* OS Support
* Author
* Category
* TRMM Arguments
* TRMM Environment
* Changelog

### Example Bash Header

For bash scripts, ensure there is no empty line within the header content.
Each line must be prefixed with a '#' to ensure the entire block is seen as the file header.

```bash
#!/bin/bash
#
# Some Title [Linux]
#
# Some description of this script and any details the operator should know.
#
# Supports:
#   Linux-All
#
# Category:
#   Security
#
# License:
#   AGPLv3
#
# Author:
#   Charlie Powell <cdp1337@bitsnbytes.dev>
#
# Link:
#   https://github.com/eVAL-Agency/ScriptsCollection
#
# Changelog:
#   2026.09.12 - Initial version
```

### Example Powershell Header

Powershell headers are content within the first comment block.
Whitespace is allowed within this header.

```powershell
<#
.TITLE
	Some Title [Windows]

.SUPPORTS
	Windows 11, 12

.LICENSE
	AGPLv3

.CATEGORY
	Security

.SYNOPSIS
	Some description of this script and any details the operator should know.

.CHANGELOG
	2026.09.13 - Initial version
#>
```


### Syntax

Provide details about the CLI syntax for the script.
Supports integration with the compiler to generate dynamic argument parsing.

The syntax section allows you to define common argument properties such as:

* Name of variable within script
* Name of variable on CLI
* Type of variable (str, int, etc)
* Default value if not set
* Optional/required values


#### Bash-Specific Syntax

Adding `# compile:argparse` to the script will generate a dynamic argument parser for the script.

Optionally, you can include the destination variable name before each argument
to allow for dynamic generation of the argument parsing via `compile:argparse`.

In this example, passing `--noninteractive` will set the variable `NONINTERACTIVE` to `1`.

(The compiler will filter out the prefix)

```bash
#/bin/bash
# ...
# Syntax:
#   NONINTERACTIVE=--noninteractive - Run in non-interactive mode, (will not ask for prompts)
#   VERSION=--version=<string> - Version of Zabbix to install (5.0|6.0|7.0|latest) DEFAULT=7.0
#   ZABBIX_SERVER=--server=<string> - Hostname or IP of Zabbix server (optional unless non-interactive)
#   ZABBIX_AGENT_HOSTNAME=--hostname=<string> - Hostname of local device for matching with a Zabbix host entry (optional unless non-interactive)
# ...

# compile:argparse
```

Generates:

```bash
#/bin/bash
# ...
# Syntax:
#   --noninteractive  - Run in non-interactive mode, (will not ask for prompts)
#   --version=<string> - Version of Zabbix to install (5.0|6.0|7.0|latest) DEFAULT=7.0
#   --server=<string> - Hostname or IP of Zabbix server (optional unless non-interactive)
#   --hostname=<string> - Hostname of local device for matching with a Zabbix host entry (optional unless non-interactive)
# ...

# Parse arguments
NONINTERACTIVE=0
VERSION="7.0"
ZABBIX_SERVER=""
ZABBIX_AGENT_HOSTNAME=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--noninteractive) NONINTERACTIVE=1;;
		--version=*|--version)
			[ "$1" == "--version" ] && shift 1 && VERSION="$1" || VERSION="${1#*=}"
			[ "${VERSION:0:1}" == "'" ] && [ "${VERSION:0-1}" == "'" ] && VERSION="${VERSION:1:-1}"
			[ "${VERSION:0:1}" == '"' ] && [ "${VERSION:0-1}" == '"' ] && VERSION="${VERSION:1:-1}"
			;;
		--server=*|--server)
			[ "$1" == "--server" ] && shift 1 && ZABBIX_SERVER="$1" || ZABBIX_SERVER="${1#*=}"
			[ "${ZABBIX_SERVER:0:1}" == "'" ] && [ "${ZABBIX_SERVER:0-1}" == "'" ] && ZABBIX_SERVER="${ZABBIX_SERVER:1:-1}"
			[ "${ZABBIX_SERVER:0:1}" == '"' ] && [ "${ZABBIX_SERVER:0-1}" == '"' ] && ZABBIX_SERVER="${ZABBIX_SERVER:1:-1}"
			;;
		--hostname=*|--hostname)
			[ "$1" == "--hostname" ] && shift 1 && ZABBIX_AGENT_HOSTNAME="$1" || ZABBIX_AGENT_HOSTNAME="${1#*=}"
			[ "${ZABBIX_AGENT_HOSTNAME:0:1}" == "'" ] && [ "${ZABBIX_AGENT_HOSTNAME:0-1}" == "'" ] && ZABBIX_AGENT_HOSTNAME="${ZABBIX_AGENT_HOSTNAME:1:-1}"
			[ "${ZABBIX_AGENT_HOSTNAME:0:1}" == '"' ] && [ "${ZABBIX_AGENT_HOSTNAME:0-1}" == '"' ] && ZABBIX_AGENT_HOSTNAME="${ZABBIX_AGENT_HOSTNAME:1:-1}"
			;;
		-h|--help) usage;;
		*) echo "Unknown argument: $1" >&2; usage;;
	esac
	shift 1
done
```

Additionally, the syntax section is used to generate the usage() function
when the following comment is included:

```bash
# compile:usage
```

This will be replaced with the following generated code based on the Symtax group:

```bash
function usage() {
  cat >&2 <<EOD
Usage: $0 [options]

Options:
    --noninteractive  - Run in non-interactive mode, (will not ask for prompts)
    --version=<string> - Version of Zabbix to install (5.0|6.0|7.0|latest) DEFAULT=7.0
    --server=<string> - Hostname or IP of Zabbix server (optional unless non-interactive)
    --hostname=<string> - Hostname of local device for matching with a Zabbix host entry (optional unless non-interactive)
EOD
  exit 1
}
```

It is recommended to use both usage and argparse to make use of both features:

```bash
# Syntax:
#    ...

# compile:usage
# compile:argparse
```

#### Python-Specific Syntax

```python
#!/usr/bin/env python3
"""

...

Syntax:
	--user=<str> - The user account to authorize the SSH key for DEFAULT=root
	--type=<str> - The SSH key to authorize DEFAULT=ecdsa

"""

...

import argparse

parser = argparse.ArgumentParser(
	prog='linux_util_ssh_get_key.py',
	description='Retrieve the public SSH key for a given user account')
# compile:argparse
args = parser.parse_args()
```

Will replace 'compile:argparse' with the following generated code:

```python
# Parse arguments
parser.add_argument('--user', type=str, help='The user account to authorize the SSH key for', default='root')
parser.add_argument('--type', type=str, help='The SSH key to authorize', default='ecdsa')
```

**Assumptions:** Uses argparse.ArgumentParser and expects the variable to be called `parser`.


### TRMM Arguments

Lists the default arguments and their values to be used when running the script in TRMM.

DOES support TRMM variable replacement for site, client, and agent.
To use these, wrap the variable in double curly braces, like so: `{{client.zabbix_hostname}}`

```bash
#/bin/bash
# ...
# TRMM Arguments:
#   --option1
#   --option2=something
```

```python
#!/usr/bin/env python3
"""
...
Syntax:
	--option1 - Short description of option 1
	--option2=... - Short description of option 2
"""
```

### TRMM Environment

Behaves the same as TRMM Arguments, but is used for environment variables.

```bash
#/bin/bash
# ...
# TRMM Environment:
#   VAR1=something
#   VAR2={{client.zabbix_hostname}}
```

```python
#!/usr/bin/env python3
"""
...
TRMM Environment:
	VAR1=something
	VAR2={{client.zabbix_hostname}}
"""
```

### Supports

Lists the OS support for the script.

```bash
#/bin/bash
# ...
# Supports:
#   Debian 12
#   Ubuntu 24.04
```

```python
#!/usr/bin/env python3
"""
...
Supports:
	Debian 12
	Ubuntu 24.04
"""
```

Distros can be listed individually, or one of the group declarations for multiple distros.

* Linux-All - All Linux-based distros (completely os-agnostic script)
* Debian-All - Any Debian-based distro (Debian, Ubuntu, Mint, etc)
* RHEL-All - Any Red Hat-based distro (RHEL, CentOS, Fedora, etc)
* ArchLinux / arch
* CentOS
* Debian
* Fedora
* LinuxMint
* RedHat / RHEL
* Rocky / RockyLinux
* SuSE / OpenSuSE
* Ubuntu
* Windows

### Author Tag

```bash
#/bin/bash
# ...
# Author:
#   Some Name <some-email@domain.tld>
```

alternative syntax:

```bash
#/bin/bash
# ...
# @AUTHOR  Some Name <some-email@domain.tld>
```

```python
#!/usr/bin/env python3
"""
...
@AUTHOR  Some Name <some-email@domain.tld>
"""
```

### Category Tag

```bash
#/bin/bash
# ...
# Category:
#   Some Category
```

alternative syntax:

```bash
#/bin/bash
# ...
# @CATEGORY  Some Category
```

```python
#!/usr/bin/env python3
"""
...
Category:
	Some Category
"""
```

### TRMM Timeout Setting

```bash
#/bin/bash
# ...
# @TRMM-TIMEOUT  120
```

```python
#!/usr/bin/env python3
"""
...
@TRMM-TIMEOUT  120
"""
```

### Draft

Set to true to skip finalizing of the script.
The script will still be generated to dist/, but will not be recorded in the README and TRMM metafile.

```bash
#/bin/bash
# ...
# Draft:
#   True
```

```python
#!/usr/bin/env python3
"""
...
Draft:
	True
"""
```


## Scriptlets

Scriptlets are small pieces of reusable code that can be included in scripts during compilation.
This system provides a number of scripts, and more can be added by adding a `compile.sources` file in the root of the project
with the format:

```
scriptlet_type=github:repo_owner/repo_name
```

Where `scriptlet_type` is the directory that contains the scriptlets to include.

By default `main` is used to download sources, but a different branch can be specified by appending `:branch_name`.

