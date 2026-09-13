<#
.TITLE
	Block Bad IPs [Windows]

.SUPPORTS
	Windows

.LICENSE
	AGPLv3

.CATEGORY
	Security

.SYNOPSIS
    Block Bad IPs [Windows]

    Ported from Linux Bash script.
    Adds firewall rules to block known bad-IPs using Windows Defender Firewall.

    Sources:
    - Tor Onionoo service
    - Spamhaus DROP list
    - CI Army (CINS)

    Requirements: Must be run as Administrator.

.CHANGELOG
	2026.09.13 - Initial version
#>

# Ensure script is running with Administrative privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Error "This script must be run as an Administrator."
	exit 1
}


# --- Helper Functions ---

function Test-IsValidIP {
	param([string]$IP)
	# Regex for IPv4 and CIDR notation
	$regex = '^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$'
	if ($IP -match $regex) {
		$parts = $IP.Split('/')
		$address = $parts[0]
		$octets = $address.Split('.')
		foreach ($octet in $octets) {
			if ([int]$octet -gt 255) { return $false }
		}
		if ($parts.Count -eq 2 -and [int]$parts[1] -gt 32) { return $false }
		return $true
	}
	return $false
}

function Update-FirewallRule {
	param (
		[string]$RuleName,
		[string[]]$IPList
	)

	if ($IPList.Count -eq 0) {
		Write-Warning "No valid IPs found for $RuleName. Removing existing rule if it exists."
		if (Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue) {
			Remove-NetFirewallRule -Name $RuleName
		}
		return
	}

	Write-Host "Updating Firewall Rule: $RuleName ($($IPList.Count) IPs)" -ForegroundColor Cyan

	# Check if rule exists
	$existingRule = Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue

	if ($null -eq $existingRule) {
		# Create new rule to Drop incoming traffic from these remote addresses
		New-NetFirewallRule -Name $RuleName `
                            -DisplayName $RuleName `
                            -Direction Inbound `
                            -Action Block `
                            -RemoteAddress $IPList `
                            -Description "Automatically updated bad IP list"
	} else {
		# Update existing rule with the new address list
		Set-NetFirewallRule -Name $RuleName -RemoteAddress $IPList
	}
}

# --- Main Logic ---

# 1. Tor Exit Nodes
try {
	Write-Host "Downloading IP list for Tor exit nodes..." -ForegroundColor Yellow
	$torUrl = "https://onionoo.torproject.org/details?search=type:relay%20running:true"
	$torData = Invoke-RestMethod -Uri $torUrl -ErrorAction Stop

	$torIPs = @()
	# Logic: Select relays where flags contains 'Exit', then grab exit_addresses
	foreach ($relay in $torData.relays) {
		if ($relay.flags -contains "Exit") {
			foreach ($ip in $relay.exit_addresses) {
				if (Test-IsValidIP -IP $ip) { $torIPs += $ip }
			}
		}
	}
	Update-FirewallRule -RuleName "Block_Tor_Exits" -IPList $torIPs
} catch {
	Write-Error "Failed to update Tor exit nodes: $($_.Exception.Message)"
}

# 2. Spamhaus DROP List
try {
	Write-Host "Downloading IP list for Spamhaus DROP data..." -ForegroundColor Yellow
	$spamUrl = "https://www.spamhaus.org/drop/drop_v4.json"
	$spamData = Invoke-RestMethod -Uri $spamUrl -ErrorAction Stop

	$spamIPs = @()
	# Iterate through the JSON and find CIDR entries
	foreach ($entry in $spamData) {
		if ($entry.cidr -and (Test-IsValidIP -IP $entry.cidr)) {
			$spamIPs += $entry.cidr
		}
	}
	Update-FirewallRule -RuleName "Block_Spamhaus_DROP" -IPList $spamIPs
} catch {
	Write-Error "Failed to update Spamhaus DROP: $($_.Exception.Message)"
}

# 3. CINS Threat Data
try {
	Write-Host "Downloading IP list for CINS threat data..." -ForegroundColor Yellow
	$cinsUrl = "http://cinsscore.com/list/ci-badguys.txt"
	$cinsContent = Invoke-WebRequest -Uri $cinsUrl -ErrorAction Stop

	# Split text into lines and clean up whitespace
	$cinsIPs = $cinsContent.Content -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

	$validCinsIPs = @()
	foreach ($ip in $cinsIPs) {
		if (Test-IsValidIP -IP $ip) { $validCinsIPs += $ip }
	}
	Update-FirewallRule -RuleName "Block_CINS_Threats" -IPList $validCinsIPs
} catch {
	Write-Error "Failed to update CINS threat data: $($_.Exception.Message)"
}

Write-Host "Firewall update process complete." -ForegroundColor Green
