# Scripts Collection Development

This describes how to work within this collection to compile deployment-ready scripts.

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

Will compile each script into a single distributable file with all dependencies included within.

```bash
python3 compile.py

# or just directly if chmod +x
./compile.py
```

## Script Metadata

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


### Script Header

The first non-empty line retrieved from the script will be used as the title, (one line only).

### Syntax

Lists how to run the application to the end user, and gets saved in the help icon in TRMM.

```bash
#/bin/bash
# ...
# Syntax:
#   --option1 - Short description of option 1
#   --option2=... - Short description of option 2
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

#### Argument Parsing

Adding `# compile:argparse` to the script will generate a dynamic argument parser for the script.

(BASH only) Optionally, you can include the destination variable name before each argument
to allow for dynamic generation of the argument parsing via `compile:argparse`.

In this example, passing `--noninteractive` will set the variable `NONINTERACTIVE` to `1`.

(The compiler will filter out the prefix)

```bash
#/bin/bash
# ...
# Syntax:
#   NONINTERACTIVE=--noninteractive - Run in non-interactive mode, (will not ask for prompts)
#   VERSION=--version=... - Version of Zabbix to install DEFAULT=7.0
#   ZABBIX_SERVER=--server=... - Hostname or IP of Zabbix server
#   ZABBIX_AGENT_HOSTNAME=--hostname=... - Hostname of local device for matching with a Zabbix host entry
# ...

# compile:argparse
```

Generates:

```bash
#/bin/bash
# ...
# Syntax:
#   --noninteractive - Run in non-interactive mode, (will not ask for prompts)
#   --version=... - Version of Zabbix to install DEFAULT=7.0
#   --server=... - Hostname or IP of Zabbix server
#   --hostname=... - Hostname of local device for matching with a Zabbix host entry
# ...

# Parse arguments
NONINTERACTIVE="0"
VERSION="7.0"
ZABBIX_SERVER=""
ZABBIX_AGENT_HOSTNAME=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--noninteractive) NONINTERACTIVE=1; shift 1;;
		--version=*) VERSION="${1#*=}"; shift 1;;
		--server=*) ZABBIX_SERVER="${1#*=}"; shift 1;;
		--hostname=*) ZABBIX_AGENT_HOSTNAME="${1#*=}"; shift 1;;
		-h|--help) usage;;
	esac
done
if [ -z "$SOURCE" ]; then
	usage
fi
```

```python
#!/usr/bin/env python3
"""
Do something

Syntax:
	--arg1=<str> - Some parameter DEFAULT=yup
	--arg2=<int> - The SSH key to authorize DEFAULT=42
"""

import argparse

# ...

parser = argparse.ArgumentParser(
	prog='scriptname.py',
	description='Does a thing')
# compile:argparse
args = parser.parse_args()
```

#### Variable Type

To support Python, ensure a variable type is specified, like so:

```python
#!/usr/bin/env python3
"""
Syntax:
	--option1=<str> - Short description of option 1
	--option2=<int> - Short description of option 2
"""
```

Argument types in Bash are ignored and are for reference only.

#### Defaults

The default value can be specified by appending `DEFAULT=(value)` to the argument, like so:

```bash
#/bin/bash
# ...
# Syntax:
#   --option1=<str> - Short description of option 1 DEFAULT=default_value
#   --option2=<int> - Short description of option 2 DEFAULT=42
```



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

## Generative Code

The compiler can generate dynamic code based on script comments, notably for usage and arguments

### Compile usage()

Will generate a "usage()" function with the description and syntax arguments.

```bash
# compile:usage
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

