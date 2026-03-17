#!/bin/bash
#
# Virtualmin Renew All SSL [Linux]
#
# Renew all SSL certs that are marked for auto-renewal on Virtualmin
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
#   20260307 - Only pull ENABLED domains, saves some time in processing
#   20251211 - Initial release

doms=`virtualmin list-domains --name-only --with-feature letsencrypt_renew --enabled`;
for dom in $doms; do
    virtualmin generate-letsencrypt-cert --domain $dom --renew ;
done