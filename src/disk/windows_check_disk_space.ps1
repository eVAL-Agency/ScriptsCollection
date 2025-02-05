<#
.TITLE
	Check Disk Space [Windows]

.DESCRIPTION
	Checks if local drives are full

.SUPPORTS
	Windows (All)

.TRMM ARGUMENTS
	-threshold 20

.CATEGORY
	Disks

.SYNTAX
	-threshold <int> - The percentage of free space that is considered a warning

.LICENSE
	AGPLv3

.AUTHOR
	Charlie Powell <cdp1337@veraciousnetwork.com>

.CHANGELOG
	20250130 - Initial version
#>

param (
	[int]$threshold = 20
)

$RetStatus = 0

$Disks = (Get-CimInstance -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3})

Foreach ($Disk in $Disks) {
	$FreePercentage = [math]::Round($Disk.FreeSpace / $Disk.Size * 100)
	if ($FreePercentage -le $threshold) {
		$RetStatus = 1
		Write-Output "WARNING - Drive $($Disk.DeviceID) ($($Disk.VolumeName)) has $($FreePercentage)% free space remaining"
	}
	else {
		Write-Output "Drive $($Disk.DeviceID) ($($Disk.VolumeName)) has $($FreePercentage)% free space remaining"
	}
}

Exit($RetStatus)