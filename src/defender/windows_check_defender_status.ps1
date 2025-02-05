<#
.TITLE
	Check Defender Status [Windows]

.DESCRIPTION
    This will check Windows Defender status for malware and antispyware reports, otherwise will report as Healthy. By default, if no command parameter is provided, it will check the last 1 day (good for a scheduled daily task).
    If a number is provided as a command parameter, it will search back that number of days provided (good for collecting all AV alerts on the computer).
    Additionally, it will use Get-MpComputerStatus to report on the overall health and status of Windows Defender.

.EXAMPLE
    -DaysBack 365 -FullScanThreshold 7 -QuickScanThreshold 1 -SignatureUpdateThreshold 1

.LICENSE
	MIT

.CATEGORY
	Security

.SUPPORTS
	Windows

.SYNTAX
	-DaysBack=<integer> - Number of days to search back for Defender alerts DEFAULT=1
	-FullScanThreshold=<integer> - Number of days since last full scan DEFAULT=7
	-QuickScanThreshold=<integer> - Number of days since last quick scan DEFAULT=1
	-SignatureUpdateThreshold=<integer> - Number of days since last signature update DEFAULT=1

.CHANGELOG
	20250204 - Initial version (in this format)
		Based on checks from dinger, bdrayer, and SDM216
    	v1 dinger initial release 2021
    	v1.1 bdrayer Adding full message output if items found
    	v1.2 added extra event IDs for ASR monitoring suggested by SDM216
    	v1.3 dinger added Get-MpComputerStatus for comprehensive Defender health status, added parameters and replaced Event Viewer checks with PowerShell commands
#>

# compile:argparse

$ErrorActionPreference = 'SilentlyContinue'
$TimeSpan = (Get-Date).AddDays(-$DaysBack)

# Check for detected threats within the date range
$threats = Get-MpThreat | Where-Object { $_.DetectionTime -ge $TimeSpan }
$issueFound = $false

if ($threats) {
	Write-Output "Defender has found threats"
	Write-Output "--------------------------------"
	$threats | Select-Object -ExpandProperty ThreatName -First 1
	$issueFound = $true
	Write-Output " "
}
else {
	Write-Output "Defender found no threats"
	Write-Output " "
}

# Check for ASR events in the Event Viewer
$asrEventFilter = @{
	LogName = 'Microsoft-Windows-Windows Defender/Operational'
	ID = '1122', '1123', '1124', '1125', '1126', '1127', '1128', '1129', '1130', '1131'
	StartTime = $TimeSpan
}

$asrEvents = Get-WinEvent -FilterHashtable $asrEventFilter

if ($asrEvents) {
	Write-Output "ASR Rule Hit Detected"
	Write-Output "--------------------------------"
	$asrEvents | Select-Object -ExpandProperty Message -First 1
	$issueFound = $true
	Write-Output " "
}

# Additional health status from Get-MpComputerStatus
$mpStatus = Get-MpComputerStatus

$defenderErrors = @()
if (-not $mpStatus.AMServiceEnabled) { $defenderErrors += "Antimalware Service is not enabled" }
if (-not $mpStatus.AntispywareEnabled) { $defenderErrors += "Antispyware is not enabled" }
if (-not $mpStatus.AntivirusEnabled) { $defenderErrors += "Antivirus is not enabled" }
if (-not $mpStatus.RealTimeProtectionEnabled) { $defenderErrors += "Real-time protection is not enabled" }
if (-not $mpStatus.NISEnabled) { $defenderErrors += "Network Inspection System is not enabled" }

if ($mpStatus.FullScanAge -gt $FullScanThreshold) {
	$defenderErrors += "Full scan has not been performed in the last $FullScanThreshold days"
}
if ($mpStatus.QuickScanAge -gt $QuickScanThreshold -and $mpStatus.FullScanAge -gt $QuickScanThreshold) {
	# Quick scan is only required if a full scan has not been performed in the last QuickScanThreshold days
	$defenderErrors += "Quick scan has not been performed in the last $QuickScanThreshold days"
}
if ($mpStatus.FullScanOverdue) {
	$defenderErrors += "Full scan is overdue"
}
if ($mpStatus.QuickScanOverdue) {
	$defenderErrors += "Quick scan is overdue"
}

# Check if signature updates are within the acceptable timeframe
if ($mpStatus.AntivirusSignatureAge -gt $SignatureUpdateThreshold) {
	$defenderErrors += "Antivirus signatures have not been updated in the last $SignatureUpdateThreshold days"
}

if ($defenderErrors.Count -gt 0) {
	Write-Output "Issues found with Windows Defender status:"
	Write-Output "--------------------------------"
	$defenderErrors | ForEach-Object { Write-Output $_ }
	$issueFound = $true
	Write-Output " "
}

if (-not $issueFound) {
	Write-Output "Defender is Healthy"
	Write-Output " "
}

# Cleanup some variables for rendering
if ($mpStatus.FullScanAge -ge 4294967295) {
	# If never ran, will report an absurdly large number instead.
	$FullScanAge = "NEVER RAN"
}
else {
	$FullScanAge = "$($mpStatus.FullScanAge) Days ago"
}

if ($mpStatus.QuickScanAge -ge 4294967295) {
	# If never ran, will report an absurdly large number instead.
	$QuickScanAge = "NEVER RAN"
}
else {
	$QuickScanAge = "$($mpStatus.QuickScanAge) Days ago"
}



Write-Output "Windows Defender Status Report:"
Write-Output "--------------------------------"
Write-Output "Service Enabled: $($mpStatus.AMServiceEnabled)"
Write-Output "Antispyware Enabled: $($mpStatus.AntispywareEnabled)"
Write-Output "Antivirus Enabled: $($mpStatus.AntivirusEnabled)"
Write-Output "Full Scan Age: $FullScanAge"
Write-Output "Quick Scan Age: $QuickScanAge"
Write-Output "Real Time Protection Enabled: $($mpStatus.RealTimeProtectionEnabled)"
Write-Output "NIS Enabled: $($mpStatus.NISEnabled)"
Write-Output "Engine Version: $($mpStatus.AMEngineVersion)"
Write-Output "Signature Version: $($mpStatus.AntivirusSignatureVersion)"

if ($issueFound) {
	exit 1
} else {
	exit 0
}
