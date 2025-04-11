<#
.TITLE
	Check Firewall Status [Windows]

.SUPPORTS
	Windows

.LICENSE
	AGPLv3

.CATEGORY
	Firewall

.CHANGELOG
	20250204 - Initial version
#>

$Ret = 0
$Profiles = $(Get-NetFirewallProfile | select Name,Enabled)
$ConnectionProfiles = $(Get-NetConnectionProfile | Select Name,NetworkCategory,IPv4Connectivity)
$AllRules = $(Get-NetFirewallRule -Action Allow -Enabled True -Direction Inbound)
$Rules = @()
$Categories = @("Any")


$Profiles | Format-Table
if (($Profiles | where { $_.Enabled -eq $True } | measure ).Count -eq 3) {
	Write-Output "Windows firewall enabled"
}
else {
	Write-Output "WARNING: Windows firewall disabled"
}

$ConnectionProfiles | Format-Table
ForEach($Profile in $ConnectionProfiles) {
	$Categories += $Profile.NetworkCategory
}

ForEach($Rule in $AllRules) {
	if ($Rule.Profile -in $Categories) {
		$Rules += $Rule
	}
}

$Rules | Format-Table -Property Name,
	@{Name='Protocol';Expression={($PSItem | Get-NetFirewallPortFilter).Protocol}},
	@{Name='LocalPort';Expression={($PSItem | Get-NetFirewallPortFilter).LocalPort}},
	@{Name='RemotePort';Expression={($PSItem | Get-NetFirewallPortFilter).RemotePort}},
	@{Name='RemoteAddress';Expression={($PSItem | Get-NetFirewallAddressFilter).RemoteAddress}},
	Enabled,Profile,Direction,Action

Exit($Ret)
