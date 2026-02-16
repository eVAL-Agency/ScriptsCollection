#!/bin/bash
#
# Check Memory Usage [Linux]
#
# Supports:
#   Linux-All
#
# Category:
#   Memory
#
# License:
#   AGPLv3
#
# Author:
#   Charlie Powell <cdp1337@veraciousnetwork.com>
#
# Syntax:
#   --threshold=<integer> - Threshold of memory used before an error is dispatched DEFAULT=20
#
# Changelog:
#   20250204 - Initial version

# Parse arguments
THRESHOLD="20"
while [ "$#" -gt 0 ]; do
	case "$1" in
		--threshold=*)
			THRESHOLD="${1#*=}";
			[ "${THRESHOLD:0:1}" == "'" ] && [ "${THRESHOLD:0-1}" == "'" ] && THRESHOLD="${THRESHOLD:1:-1}"
			[ "${THRESHOLD:0:1}" == '"' ] && [ "${THRESHOLD:0-1}" == '"' ] && THRESHOLD="${THRESHOLD:1:-1}"
			;;
		*) echo "Unknown argument: $1" >&2; usage;;
	esac
	shift 1
done


MEM="$(free -m | grep Mem)"
TOTAL="$(echo $MEM | awk '{print $2}')"
USED="$(echo $MEM | awk '{print $3}')"
FREE="$(echo $MEM | awk '{print $4}')"
SHARED="$(echo $MEM | awk '{print $5}')"
BUFF="$(echo $MEM | awk '{print $6}')"
AVAIL="$(echo $MEM | awk '{print $7}')"

PCENT=$(echo "scale=2; 100 - $USED / $TOTAL * 100" | bc)

# Print used and free to stderr for reference
if [ $USED -le 4096 ]; then
	echo "Used Memory: $(echo "$USED")MB" >&2
else
	echo "Used Memory: $(echo "$USED / 1024" | bc)GB" >&2
fi

if [ $FREE -le 4096 ]; then
	echo "Free/Unallocated Memory: $(echo "$FREE")MB" >&2
else
	echo "Free/Unallocated Memory: $(echo "$FREE / 1024" | bc)GB" >&2
fi

if [ $SHARED -le 4096 ]; then
	echo "Free/Shared Memory: $(echo "$SHARED")MB" >&2
else
	echo "Free/Shared Memory: $(echo "$SHARED / 1024" | bc)GB" >&2
fi

if [ $BUFF -le 4096 ]; then
	echo "Free/Buffer Memory: $(echo "$BUFF")MB" >&2
else
	echo "Free/Buffer Memory: $(echo "$BUFF / 1024" | bc)GB" >&2
fi

echo "Percent Free: $PCENT%" >&2

# Print percent free to stdout for logging / tracking
echo $PCENT

# Return status based if percentage free is below defined threshold
if [ $(echo "$PCENT < $THRESHOLD" | bc) -eq 1 ]; then
	exit 1
else
	exit 0
fi
