<#
.TITLE
	Check if Reboot Required [Windows]

.DESCRIPTION
	Checks if this device requires a reboot

	Requires the custom fields:
	NONE

.SUPPORTS
	Windows 10, 11

.CATEGORY
	Updates

.LICENSE
	AGPLv3

.AUTHOR
	Charlie Powell <cdp1337@veraciousnetwork.com>

.CHANGELOG
	20250130 - Initial release
#>

if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) {
	Write-Output "Reboot Pending"
	Exit(1)
}
if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) {
	Write-Output "Reboot Required"
	Exit(1)
}
if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) {
	Write-Output "Reboot Required"
	Exit(1)
}

try {
	$util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
	$status = $util.DetermineIfRebootPending()
	if (($status -ne $null) -and $status.RebootPending) {
		Write-Output "Reboot Pending"
		Exit(1)
	}
}catch{}

Write-Output "No Reboot Required"
Exit(0)