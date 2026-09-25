<#
.TITLE
    Firewall - Allow IP/Port [Windows]

.SYNOPSIS
    Allows a service and/or source in the Windows Defender Firewall.

.CATEGORY
	Security

.EXAMPLE
    .\windows_util_firewall_allow.ps1 -Port "80,443"
    Allow http/https

.EXAMPLE
    .\windows_util_firewall_allow.ps1 -Port 53 -Proto UDP
    Allow DNS

.EXAMPLE
    .\windows_util_firewall_allow.ps1 -IP "5.4.5.4"
    Whitelist IP

.EXAMPLE
    .\windows_util_firewall_allow.ps1 -IP "5.4.5.4" -Port 22
    Allow IP to access port 22

.PARAMETER IP
    IP address or CIDR network to allow. Defaults to Any.

.PARAMETER Port
    Port(s) to allow (comma-separated string).

.PARAMETER Proto
    Protocol to allow (TCP or UDP). Defaults to TCP.

.PARAMETER Comment
    Optional description for the rule.

.LICENSE
    AGPLv3
#>

Param(
	[Parameter(Mandatory=$false)]
	[string]$IP = "Any",

	[Parameter(Mandatory=$false)]
	[string]$Port = $null,

	[Parameter(Mandatory=$false)]
	[ValidateSet("TCP", "UDP")]
	[string]$Proto = "TCP",

	[Parameter(Mandatory=$false)]
	[string]$Comment = ""
)

# --- Shared Functionality ---

# scriptlet:_common/require_root.ps1


# --- Internal Logic ---

# Validate Port input
# If ports are provided as a string "80,443", we split them into an array for PowerShell compatibility
if ($null -eq $Port) {
	Write-Error "No port specified. Use -Port parameter."
	exit 1
}
$PortArray = $Port.Split(',').Trim()

# 3. Generate a unique name for the rule to avoid collisions/duplicates
# We use a timestamp or hash if you want it truly unique, but here we create a descriptive name
$RuleName = "Allow_Inbound_$($Proto)_$($Port.Replace(',', '_'))"
if ($IP -ne "Any") { $RuleName += "_From_$($IP.Replace('.', '_'))" }

# 4. Construct the Rule Parameters
$RuleParams = @{
	DisplayName = $RuleName
	Direction   = 'Inbound'
	Action      = 'Allow'
	Protocol    = $True # We will set specific protocol below
	LocalPort   = $PortArray
	RemoteAddress = $IP
}

# If a comment is provided, we use it as the Description
if (-not [string]::IsNullOrWhiteSpace($Comment)) {
	$RuleParams["Description"] = $Comment
}

# 5. Execute Firewall Action
try {
	Write-Host "Attempting to create firewall rule: $RuleName" -ForegroundColor Cyan

	# Check if rule already exists to prevent errors (Equivalent to checking firewall_action)
	$existingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
	if ($existingRule) {
		Write-Warning "A rule with this name already exists. It may be updated or skipped."
		# Optionally: Remove-NetFirewallRule -DisplayName $RuleName
	} else {
		# Create the new rule
		New-NetFirewallRule @RuleParams -Protocol $Proto -ErrorAction Stop | Out-Null
		Write-Host "Successfully allowed $Port ($Proto) from $IP." -ForegroundColor Green
	}
}
catch {
	Write-Error "Failed to create firewall rule. Error: $_"
	exit 1
}
