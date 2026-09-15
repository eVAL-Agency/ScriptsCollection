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

# scriptlet:_common/require_root.ps1


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

function Remove-NetFirewallRuleWithLog {
	param([Parameter(ValueFromPipeline)]$Rule)
	process {
		if ($null -ne $Rule) {
			Write-Host "Removing Firewall Rule: $($Rule.DisplayName)" -ForegroundColor Gray
			$Rule | Remove-NetFirewallRule
		}
	}
}

function Update-FirewallRule {
	param (
		[string]$RuleName,
		[string]$RuleDescription,
		[string[]]$IPList
	)

	$chunkSize = 2000
	$useChunks = $false
	$chunks = @()

	if ($IPList.Count -eq 0) {
		Write-Warning "No valid IPs found for $RuleName. Removing existing rule if it exists."
		Get-NetFirewallRule -DisplayName "$RuleName_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRuleWithLog
		Get-NetFirewallRule -DisplayName "$RuleName" -ErrorAction SilentlyContinue | Remove-NetFirewallRuleWithLog
		return
	}

	Write-Host "Updating Firewall Rule: $RuleName ($( $IPList.Count ) IPs)" -ForegroundColor Cyan

	if ($IPList.Count -gt $chunkSize) {
		# This list contains more rules than allowed in each Windows Defender list.
		# remove any non-chunked ruleset and create the new chunks.
		Get-NetFirewallRule -DisplayName "$RuleName" -ErrorAction SilentlyContinue | Remove-NetFirewallRuleWithLog
		$useChunks = $true

		for ($i = 0; $i -lt $IPList.Count; $i += $chunkSize) {
			# Calculate the end of the current chunk
			$endIndex = [Math]::Min($i + $chunkSize - 1, $IPList.Count - 1)

			# Extract the slice of IPs for this batch
			$currentChunk = $IPList[$i..$endIndex]

			# Create a unique name for this specific chunk (e.g., Block_Spamhaus_DROP_0, _1, etc.)
			$chunkIndex = [Math]::Floor($i / $chunkSize)
			$currentRuleName = "$RuleName`_$chunkIndex"

			$chunks += @{
				Name = $currentRuleName
				DisplayName = $currentRuleName
				IPs = $currentChunk
			}
		}
	}
	else {
		# List is smaller than the max chunksize.
		# Just create the full list as a chunk.
		Get-NetFirewallRule -DisplayName "${RuleName}_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRuleWithLog
		$useChunks = $false
		$chunks += @{
			Name = $RuleName
			DisplayName = $RuleName
			IPs = $IPList
		}
	}

	# Iterate over the internal collection to create the rules
	foreach ($chunk in $chunks) {
		# Check if rule exists
		$existingRule = Get-NetFirewallRule -Name $chunk.Name -ErrorAction SilentlyContinue

		if ($null -eq $existingRule) {
			# Create new rule to Drop incoming traffic from these remote addresses
			New-NetFirewallRule -Name $chunk.Name `
                            -DisplayName $chunk.DisplayName `
                            -Direction Inbound `
                            -Action Block `
                            -RemoteAddress $chunk.IPs `
                            -Description $RuleDescription
		}
		else {
			# Update existing rule with the new address list
			Set-NetFirewallRule -Name $chunk.Name -RemoteAddress $chunk.IPs
		}
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
	Update-FirewallRule `
		-RuleName "Block_Tor_Exits" `
		-RuleDescription "Blocklist of Tor exit nodes" `
		-IPList $torIPs
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
	foreach ($line in ($spamData -Split "`r?`n")) {
		$entry = $line | ConvertFrom-Json
		if ($entry.cidr -and (Test-IsValidIP -IP $entry.cidr)) {
			$spamIPs += $entry.cidr
		}
	}
	Update-FirewallRule `
		-RuleName "Block_Spamhaus_DROP" `
		-RuleDescription "Spamhaus Dont-Route-Or-Peer list - (c) The Spamhaus Project SLU" `
		-IPList $spamIPs
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
	Update-FirewallRule `
		-RuleName "Block_CINS_Threats" `
		-RuleDescription "CINS Active Threat list - https://www.ciarmy.com/" `
		-IPList $validCinsIPs
} catch {
	Write-Error "Failed to update CINS threat data: $($_.Exception.Message)"
}

Write-Host "Firewall update process complete." -ForegroundColor Green
