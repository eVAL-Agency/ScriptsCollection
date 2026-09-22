function Test-IsRebootPending {
	<#
    .SYNOPSIS
        Checks if the Windows operating system is in a state that requires a reboot.

    .DESCRIPTION
        Scans registry keys related to Windows Update, CBS, and Pending File Rename
        operations to determine if a restart is necessary to complete installations.

    .OUTPUTS
        System.Boolean. True if a reboot is required, False otherwise.
    #>
	[CmdletBinding()]
	param()

	# 1. Check Windows Update Reboot Key
	if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
		Write-Verbose "Found Windows Update reboot requirement."
		return $true
	}

	# 2. Check Component Based Servicing (CBS) - Used by Install-WindowsFeature
	if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
		Write-Verbose "Found CBS/Feature installation reboot requirement."
		return $true
	}

	# 3. Check Pending File Rename Operations
	# This is a classic way installers (like Docker or drivers) signal a rename is needed on next boot
	$renameOp = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
	if ($null -ne $renameOp -and $null -ne $renameOp.PendingFileRenameOperations) {
		Write-Verbose "Found Pending File Rename operations."
		return $true
	}

	# 4. Check ShutdownExecute (Used by some third-party installers to run commands at shutdown/startup)
	if (Test-Path "HKLM:\System\CurrentControlSet\Control\Session Manager\ShutdownExecute") {
		Write-Verbose "Found ShutdownExecute pending command."
		return $true
	}

	return $false
}