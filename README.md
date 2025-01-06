# Scripts Collection

A collection of useful scripts for various Linux distributions

## Scripts

| Category | Script | Type | Supports |
|----------|--------|------|----------|
| Game Server | [Install ARK Survival Ascended Dedicated Server](dist/game-arksurvivalascended/README.md) | Shell | ![debian](.supplemental/images/icons/debian.svg "Debian 12") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Ubuntu 24.04") |
| Game Server | [Install Project Zomboid](dist/game-projectzomboid/linux_install_game_zomboid.sh) | Shell | ![debian](.supplemental/images/icons/debian.svg "Debian 12") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Ubuntu 24.04") |
| Hardware | [Disk Drive Health Check](dist/disk/linux_check_disk_health.sh) | Shell | ![archlinux](.supplemental/images/icons/archlinux.svg "Arch") ![centos](.supplemental/images/icons/centos.svg "RHEL-All") ![debian](.supplemental/images/icons/debian.svg "Debian-All") ![fedora](.supplemental/images/icons/fedora.svg "RHEL-All") ![linuxmint](.supplemental/images/icons/linuxmint.svg "Debian-All") ![redhat](.supplemental/images/icons/redhat.svg "RHEL-All") ![rocky](.supplemental/images/icons/rocky.svg "RHEL-All") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Debian-All") |
| Security | [Firewall - Check Status](dist/firewall/linux_check_firewall.sh) | Shell | ![archlinux](.supplemental/images/icons/archlinux.svg "Linux-All") ![centos](.supplemental/images/icons/centos.svg "Linux-All") ![debian](.supplemental/images/icons/debian.svg "Linux-All") ![fedora](.supplemental/images/icons/fedora.svg "Linux-All") ![linuxmint](.supplemental/images/icons/linuxmint.svg "Linux-All") ![redhat](.supplemental/images/icons/redhat.svg "Linux-All") ![rocky](.supplemental/images/icons/rocky.svg "Linux-All") ![suse](.supplemental/images/icons/suse.svg "Linux-All") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Linux-All") |
| Security | [Install Firewall (UFW)](dist/ufw/linux_install_ufw.sh) | Shell | ![archlinux](.supplemental/images/icons/archlinux.svg "Linux-All") ![centos](.supplemental/images/icons/centos.svg "Linux-All") ![debian](.supplemental/images/icons/debian.svg "Linux-All") ![fedora](.supplemental/images/icons/fedora.svg "Linux-All") ![linuxmint](.supplemental/images/icons/linuxmint.svg "Linux-All") ![redhat](.supplemental/images/icons/redhat.svg "Linux-All") ![rocky](.supplemental/images/icons/rocky.svg "Linux-All") ![suse](.supplemental/images/icons/suse.svg "Linux-All") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Linux-All") |
| System Monitoring | [Install Zabbix Agent2](dist/zabbix/linux_install_zabbix_agent2.sh) | Shell | ![centos](.supplemental/images/icons/centos.svg "CentOS 8, 9") ![debian](.supplemental/images/icons/debian.svg "Debian 12") ![redhat](.supplemental/images/icons/redhat.svg "RHEL 8, 9") ![rocky](.supplemental/images/icons/rocky.svg "Rocky 8, 9") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Ubuntu 24.04") |
| System Monitoring | [Install Zabbix Proxy](dist/zabbix/linux_install_zabbix_proxy.sh) | Shell | ![centos](.supplemental/images/icons/centos.svg "CentOS 8, 9") ![debian](.supplemental/images/icons/debian.svg "Debian 12") ![redhat](.supplemental/images/icons/redhat.svg "RHEL 8, 9") ![rocky](.supplemental/images/icons/rocky.svg "Rocky 8, 9") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Ubuntu 24.04") |
| User Management | [Authorize SSH key for a user](dist/ssh/linux_util_ssh_authorize.py) | Python | ![archlinux](.supplemental/images/icons/archlinux.svg "Linux-All") ![centos](.supplemental/images/icons/centos.svg "Linux-All") ![debian](.supplemental/images/icons/debian.svg "Linux-All") ![fedora](.supplemental/images/icons/fedora.svg "Linux-All") ![linuxmint](.supplemental/images/icons/linuxmint.svg "Linux-All") ![redhat](.supplemental/images/icons/redhat.svg "Linux-All") ![rocky](.supplemental/images/icons/rocky.svg "Linux-All") ![suse](.supplemental/images/icons/suse.svg "Linux-All") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Linux-All") |
| User Management | [Firewall - Whitelist IP](dist/firewall/linux_util_firewall_whitelist_ip.sh) | Shell | ![archlinux](.supplemental/images/icons/archlinux.svg "Linux-All") ![centos](.supplemental/images/icons/centos.svg "Linux-All") ![debian](.supplemental/images/icons/debian.svg "Linux-All") ![fedora](.supplemental/images/icons/fedora.svg "Linux-All") ![linuxmint](.supplemental/images/icons/linuxmint.svg "Linux-All") ![redhat](.supplemental/images/icons/redhat.svg "Linux-All") ![rocky](.supplemental/images/icons/rocky.svg "Linux-All") ![suse](.supplemental/images/icons/suse.svg "Linux-All") ![ubuntu](.supplemental/images/icons/ubuntu.svg "Linux-All") |
| Uncategorized | [src/test-firewall/test.sh](dist/test-firewall/test.sh) | Shell |  |

## Compile all scripts

Will compile each script into a single distributable file with all dependencies included within.

```bash
python3 compile.py
```

## Script Metadata

Most of the metadata is collected from the file header.
To ensure rendering, please ensure all file headers start with `# `,
and separating lines contain a `#`.

Header scanning will stop as soon as an empty line is encountered.

Example, this will **not** see the "Supports" section as a header field, and thus will not include it.

```bash
#!/bin/bash
#
# Some title

# Supports:
#    Debian 12
```

Correct form includes a '#' to ensure the entire block is seen as the file header.

```bash
#!/bin/bash
#
# Some title
#
# Supports:
#    Debian 12
```

### Script Header

The first non-empty line retrieved from the script will be used as the title, (one line only).

### Syntax

Lists how to run the application to the end user, and gets saved in the help icon in TRMM.

```bash
# Syntax:
#   --option1 - Short description of option 1
#   --option2=... - Short description of option 2
```

Optionally, you can include the destination variable name before each argument
to allow for dynamic generation of the argument parsing via `compile:argparse`.

In this example, passing `--noninteractive` will set the variable `NONINTERACTIVE` to `1`.

(The compiler will filter out the prefix)

```bash
# Syntax:
#   NONINTERACTIVE=--noninteractive - Run in non-interactive mode, (will not ask for prompts)
#   VERSION=--version=... - Version of Zabbix to install (default: 7.0)
#   ZABBIX_SERVER=--server=... - Hostname or IP of Zabbix server
#   ZABBIX_AGENT_HOSTNAME=--hostname=... - Hostname of local device for matching with a Zabbix host entry
```

When called with:

```bash
# compile:argparse
```

### TRMM Arguments

Lists the default arguments and their values to be used when running the script in TRMM.

DOES support TRMM variable replacement for site, client, and agent.
To use these, wrap the variable in double curly braces, like so: `{{client.zabbix_hostname}}`

```bash
# TRMM Arguments:
#   --option1
#   --option2=something
```

### TRMM Environment

Behaves the same as TRMM Arguments, but is used for environment variables.

```bash
# TRMM Environment:
#   VAR1=something
#   VAR2={{client.zabbix_hostname}}
```

### Supports

Lists the OS support for the script.

```bash
# Supports:
#   Debian 12
#   Ubuntu 24.04
```

Distros can be listed individually, or one of the group declarations for multiple distros.

* Linux-All - All Linux-based distros (completely os-agnostic script)
* Debian-All - Any Debian-based distro (Debian, Ubuntu, Mint, etc)
* RHEL-All - Any Red Hat-based distro (RHEL, CentOS, Fedora, etc)

### Author Tag

```bash
# @AUTHOR  Some Name <some-email@domain.tld>
```

### Category Tag

```bash
# @CATEGORY  Some Category
```

### TRMM Timeout Setting

```bash
# @TRMM-TIMEOUT  120
```

## Generative Code

The compiler can generate dynamic code based on script comments, notably for usage and arguments

### Compile usage()

Will generate a "usage()" function with the description and syntax arguments.

```bash
# compile:usage
```
