<#
.TITLE
	Check Memory Usage [Windows]

.SUPPORTS
	Windows

.CATEGORY
	Memory

.LICENSE
	AGPLv3

.AUTHOR
	Charlie Powell <cdp1337@veraciousnetwork.com>

.SYNTAX
	-Threshold=<integer> - Threshold of memory used before an error is dispatched DEFAULT=20

.CHANGELOG
	20250204 - Initial version
#>

# compile:argparse

$PCent = $(Get-Counter '\Memory\% Committed Bytes In Use').CounterSamples.CookedValue
Write-Output $PCent

if (100 - $PCent -lt $Threshold) {
	Exit(1)
} else {
	Exit(0)
}
