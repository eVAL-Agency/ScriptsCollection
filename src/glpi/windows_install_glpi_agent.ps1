<#
.TITLE
	Install GLPI Agent [Windows]

.DESCRIPTION
	Install GLPI agent on a Windows system

.SUPPORTS
	Windows 10, 11, Server 2019

.CATEGORY
	Monitoring

.LICENSE
	AGPLv3

.ARGUMENTS
	-Tag {{tagname}} - The Entity tag to associate within GLPI
	-Server {{serverurl}} - The FQDN of the GLPI server

.CHANGELOG
	2026.09.13 - Initial release

#>

[CmdletBinding()]
param (
	[Parameter(Mandatory = $true, HelpMessage = "Server URL of your GLPI instance")]
	[string]$Server,

	[Parameter(Mandatory = $true, HelpMessage = "Tag in GLPI to associated this device with")]
	[string]$Tag
)

# ==============================================================================
# CONFIGURATION
# ==============================================================================
$Version = "1.19"
$DownloadUrl = "https://github.com/glpi-project/glpi-agent/releases/download/$Version/GLPI-Agent-$Version-x64.msi"
$TempFolder  = [System.IO.Path]::GetTempPath()
$MsiName     = "GLPI-Agent.msi"
$Destination = Join-Path -Path $TempFolder -ChildPath $MsiName
$LogFile     = Join-Path -Path $TempFolder -ChildPath "msi_install_log.txt"
# Define the path your calling system checks for an existing installation
$GlpiDir = "${env:ProgramFiles}\GLPI-Agent"

Write-Host "Using parameters from arguments:"
Write-Host "Server URL: $Server"
Write-Host "GLPI Tag: $Tag"

# ==============================================================================
# STEP 1: DOWNLOAD THE MSI
# ==============================================================================
Write-Host "Starting download from: $DownloadUrl" -ForegroundColor Cyan

try {
	# Force TLS 1.2/1.3 for modern GitHub connections
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

	# Download the file
	Invoke-WebRequest -Uri $DownloadUrl -OutFile $Destination -UseBasicParsing
	Write-Host "Download completed successfully. Saved to: $Destination" -ForegroundColor Green
}
catch {
	Write-Error "Failed to download the file. Error: $_"
	Exit 1
}

# ==============================================================================
# STEP 2: EXECUTE THE MSI INSTALLER
# ==============================================================================
Write-Host "Starting silent installation..." -ForegroundColor Cyan

# Define msiexec arguments for a silent install with logging
# /i = Install, /qn = Quiet/No UI, /norestart = Prevent sudden reboots
$InstallerArgs = @(
	"/i", "`"$Destination`"",
	"/qn",
	"/norestart",
	"/log", "`"$LogFile`"",
	"SERVER=`"$Server`"",
	"NO_HTTPD=1",
	"RUNNOW=1",
	"TAG=`"$Tag`""
)

# If the directory exists, append the MSI property to force a reconfiguration
if (Test-Path -Path $GlpiDir) {
	Write-Host "Existing GLPI directory detected at $GlpiDir. Injecting update properties..." -ForegroundColor Yellow

	# REINSTALLMODE=vamus updates all files, registry keys, and shortcuts regardless of version [1]
	$InstallerArgs += "REINSTALL=feat_AGENT"
}


try {
	# Start the process and wait for it to finish
	$Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $InstallerArgs -Wait -Passthru

	# Check the exit code
	# 0 = Success, 3010 = Success but reboot required
	if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
		Write-Host "Installation completed successfully! (Exit Code: $($Process.ExitCode))" -ForegroundColor Green
	} else {
		Write-Error "Installation failed with exit code $($Process.ExitCode). Check log at: $LogFile"
		Exit $Process.ExitCode
	}
}
catch {
	Write-Error "Failed to execute the installer. Error: $_"
	Exit 1
}
