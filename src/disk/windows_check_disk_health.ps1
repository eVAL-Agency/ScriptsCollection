<#
.TITLE
	Check Disk Health [Windows]

.SUPPORTS
	Windows

.LICENSE
	AGPLv3

.CATEGORY
	Disks

.CHANGELOG
	20250204 - Initial version
#>

$Disks = Get-PhysicalDisk
$Ret = 0

Write-Output $Disks

foreach ($Disk in $Disks) {
	if ($Disk.HealthStatus -ne "Healthy") {
		$Ret = 1
	}
}
Exit($Ret)
