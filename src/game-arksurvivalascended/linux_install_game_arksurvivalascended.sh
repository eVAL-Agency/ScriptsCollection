#!/bin/bash
#
# Install ARK Survival Ascended Dedicated Server
#
# Uses Glorious Eggroll's build of Proton
# Please ensure to run this script as root (or at least with sudo)
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @SOURCE  https://github.com/cdp1337/ARKSurvivalAscended-Linux
# @CATEGORY Game Server
# @TRMM-TIMEOUT 600
#
# F*** Nitrado
#
# Supports:
#   Debian 12
#   Ubuntu 24.04
#
# Requirements:
#   None
#
# TRMM Custom Fields:
#   None
#
# Changelog:
#   20250625 - Remove all logic; this project has moved.
#   20250128 - Fix missing escape character
#   20241220 - Switch to UFW
#            - Add Extinction
#

# scriptlet:_common/require_root.sh

sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/cdp1337/ARKSurvivalAscended-Linux/main/dist/server-install-debian12.sh)" root
