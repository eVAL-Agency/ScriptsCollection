function Test-WindowsFeatureInstalled {
	param (
		[Parameter(Mandatory = $true)] [string]$Feature
	)

	try {
		if (Get-Module -ListAvailable ServerManager) {
			# Server code
			$Status = Get-WindowsFeature -Name $Feature
			if ($null -eq $Status) {
				return $false
			}
			return ($Status.InstallState -eq "Installed")
		}
		else {
			# Check for Windows Desktop
			$Status = Get-WindowsOptionalFeature -Name $Feature
			if ($null -eq $Status) {
				return $false
			}
			return ($Status.State -eq "Enabled")
		}
	} catch {
		Write-Warning "Could not verify status of feature: $feature. It may not exist."
		return $false
	}
	return $true
}
