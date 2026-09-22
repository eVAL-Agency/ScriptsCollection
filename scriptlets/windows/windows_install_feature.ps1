function WindowsInstallFeature {
	param (
		[Parameter(Mandatory = $true)] [string]$Feature
	)

	try {
		if (Get-Module -ListAvailable ServerManager) {
			# Code for Windows Server
			Write-Host "Installing $Feature (Windows Server)..." -ForegroundColor Cyan
			Install-WindowsFeature -Name Containers
		}
		else {
			# Code for Windows Desktop
			Write-Host "Installing $Feature (Windows Desktop)..." -ForegroundColor Cyan
			Enable-WindowsOptionalFeature -Online -FeatureName Containers
		}
	} catch {
		Write-Warning "Could not verify status of feature: $feature. It may not exist."
		return $false
	}
	return $true
}




