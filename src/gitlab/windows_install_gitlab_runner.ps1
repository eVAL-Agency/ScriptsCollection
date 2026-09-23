<#
.TITLE
	Install Gitlab Runner [Windows]

.SYNOPSIS
	Install Gitlab Runner on a Windows server or workstation

	Will automatically install Docker and Git as dependencies.

	To install, first browse to Admin -> CI/CD -> Runners and set up a new Runner.
	This will generate a token to use for authenticating the new connection.

.SYNTAX
	-Url https://fully.resolved.url
	ENV: GITLAB_TOKEN=runner-registration-token

.PARAMETER Url
	Fully resolved URL to the gitlab instance with to register

.ENVIRONMENT GITLAB_TOKEN
	Registration token to authorize adding this Runner.

.TIMEOUT
	600 seconds

.CATEGORY
	Software

.SUPPORTS
	Windows Server 2022, Windows 10, Windows 11
#>

Param(
	[Parameter(Mandatory=$true, Helpmessage="Parameter -Url is required for the fully resolved path to Gitlab")]
	[ValidateNotNullOrEmpty()]
	[string]$Url
)

# --- CONFIGURATION ---
# Check periodically for new versions as posted on https://git-scm.com/install/windows
$gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/Git-2.55.0.5-64-bit.exe"
$gitInstallPath = Join-Path $env:ProgramFiles "Git"
$runnerUrl = "https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/binaries/gitlab-runner-windows-amd64.exe"
$runnerDir = "C:\GitLab-Runner"

# scriptlet:_common/require_root.ps1
# scriptlet:windows/test_is_reboot_pending.ps1
# scriptlet:windows/test_windows_feature_installed.ps1
# scriptlet:windows/windows_install_feature.ps1

if ([string]::IsNullOrWhiteSpace($env:GITLAB_TOKEN)) {
	Write-Error "Environmental variable GITLAB_TOKEN is required"
	exit 1
}


if (Test-IsRebootPending) {
	shutdown.exe /r /t 10 /c "Gitlab Runner requires a reboot."
	Write-Error "Reboot is required, issuing restart command.  Please re-run script once booted."
	Restart-Computer -Force
}

if (-Not (Test-WindowsFeatureInstalled -Feature "Containers")) {
	WindowsInstallFeature -Feature "Containers"
}

if (Test-IsRebootPending) {
	shutdown.exe /r /t 10 /c "Gitlab Runner requires a reboot."
	Write-Error "Reboot is required, issuing restart command.  Please re-run script once booted."
	Restart-Computer -Force
}


# Check if Docker is installed; this is a depdendency for Runners.
$dockerService = Get-Service -Name "docker" -ErrorAction SilentlyContinue
if ($null -eq $dockerService) {
	Write-Host "Docker not detected. Starting installation process..." -ForegroundColor Cyan

	$dockerInstaller = "$env:TEMP\install-docker-ce.ps1"
	Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -o $dockerInstaller
	& $dockerInstaller
	Remove-Item $dockerInstaller -Force
} else {
	Write-Host "Docker is already installed." -ForegroundColor Green
}

# INSTALL GIT (The Self-Sustaining Way)
if (!(Test-Path $gitInstallPath)) {
	Write-Host "Git not found. Downloading..." -ForegroundColor Cyan
	$gitInstaller = "$env:TEMP\git_installer.exe"
	Invoke-Command -ScriptBlock { param($u, $d) Invoke-WebRequest -Uri $u -OutFile $d } -ArgumentList $gitUrl, $gitInstaller

	Write-Host "Running Git Silent Installation..." -ForegroundColor Cyan
	# /VERYSILENT = No UI; /NORESTART = Don't reboot the server; /DIR = Where to put it
	Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/DIR=`"$gitInstallPath`"" -Wait

	Remove-Item $gitInstaller -Force
} else {
	Write-Host "Git is already installed." -ForegroundColor Green
}

# ENSURE GIT IS IN THE SYSTEM PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$gitInstallPath*") {
	Write-Host "Adding Git to System PATH..." -ForegroundColor Cyan
	$newPath = "$currentPath;$gitInstallPath\cmd"
	[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
	$env:Path += ";$gitInstallPath\cmd" # Update current session too
}

# INSTALL GITLAB RUNNER (If not already present)
if (!(Test-Path "$runnerDir\gitlab-runner.exe")) {
	Write-Host "Installing GitLab Runner..." -ForegroundColor Cyan
	New-Item -ItemType Directory -Path $runnerDir -Force
	$runnerExe = "$runnerDir\gitlab-runner.exe"
	Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerExe

	& $runnerExe install
	& $runnerExe start

	$regArgs = @(
		"register",
		"--non-interactive",
		"--url", $Url,
		"--token", $env:GITLAB_TOKEN,
		"--executor", "docker-windows",
		"--docker-image", "mcr.microsoft.com/windows/servercore:1809_amd64",
		"--docker-pull-policy", "if-not-present"
	)

	try {
		Start-Process -FilePath $runnerExe -ArgumentList $regArgs -Wait -NoNewWindow -ErrorAction Stop
		Write-Host "Registration successful." -ForegroundColor Green
	} catch {
		Write-Error "Registration failed: $($_.Exception.Message)"
		exit 1
	}

	Set-Service -Name 'gitlab-runner' -StartupType Automatic
}

Write-Host "Provisioning Complete!" -ForegroundColor Green
