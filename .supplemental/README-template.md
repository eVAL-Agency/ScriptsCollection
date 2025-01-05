# Scripts Collection

A collection of useful scripts for various Linux distributions

## Scripts

%%SCRIPTS_TABLE%%

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

For scripts that work with any Linux distribution, use `Linux-All`.

```bash
# Supports:
#   Debian 12
#   Ubuntu 24.04
```

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
