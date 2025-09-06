<#
.TITLE
	Collect Asset Inventory (Grist) [Windows]

.DESCRIPTION
	Collect asset information for a device including CPU, memory, network, and OS details.
	This information is then sent to Grist for asset tracking.

.SUPPORTS
	Windows 10, 11

.CATEGORY
	Asset Tracking

.LICENSE
	AGPLv3

.TRMM ENVIRONMENT
	GRIST_URL={{client.grist_url}}
	GRIST_ACCOUNT={{client.grist_account}}

.CHANGELOG
	20250906 - Updated to work with Grist instead of SuiteCRM
	20250128 - Switch from single-device ID assigning to lookup via MAC to simplify deployment
	20240111 - Initial release
#>

$crm_url = $Env:GRIST_URL
$crm_client_id = $Env:GRIST_ACCOUNT

if ($crm_url -eq $null -or $crm_url -eq '') {
	Write-Host "CRM_URL is not set"
	exit(1)
}

if ($crm_client_id -eq $null -or $crm_client_id -eq '') {
	Write-Host "CRM_CLIENT_ID is not set"
	exit(1)
}

$empty_values = @(
	'',
	'00000000',
	'0123456789',
	'Default string',
	'N/A',
	'None',
	'No Asset Tag',
	'Not Applicable',
	'Not Specified',
	'System Product Name',
	'System Serial Number',
	'System Version',
	'System manufacturer',
	'Tag 12345',
	'To Be Filled By O.E.M.',
	'Unknown'
)

$data = @{}

# Load all the WMI data
$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
$Bios = Get-WmiObject -Class Win32_BIOS
$OperatingSystem = Get-WmiObject -Class Win32_OperatingSystem
$Processor = Get-WmiObject -Class Win32_Processor
$Memory = Get-WmiObject -Class Win32_PhysicalMemory
$Board = Get-WmiObject -Class Win32_BaseBoard
$Address = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }

# Process ComputerSystem/BIOS info
$data.hostname = $ComputerSystem.Name
if ($ComputerSystem.Domain -ne $null) {
	$data.hostname += '.' + $ComputerSystem.Domain
}
$data.manufacturer = $ComputerSystem.Manufacturer
$data.model = $ComputerSystem.Model
if (!($empty_values -contains $Bios.SerialNumber.trim())) {
	$data.serial = $Bios.SerialNumber
}

# Process Board info
$data.board_manufacturer = $Board.Manufacturer
$data.board_model = $Board.Product
if (!($empty_values -contains $Board.SerialNumber.trim())) {
	$data.board_serial = $Board.SerialNumber
}

# Process OS info
$data.os_name = $OperatingSystem.Caption
$data.os_version = $OperatingSystem.Version

# Process CPUs
if ($Processor.Length -gt 1) {
	$data.cpu_model = "$($Processor.Length)x $($Processor[0].Name)"
} else {
	$data.cpu_model = $Processor.Name
}
$threads = 0
foreach ($core in $Processor) {
	$threads += $core.NumberOfLogicalProcessors
}
$data.cpu_threads = $threads

# Process memory modules
$module_counts = @{}
$mem_total = 0
foreach ($module in $Memory) {
	if ($module.Capacity -eq 0) {
		$mem_label = 'Empty'
	}
	else {
		$mem_capacity = ($module.Capacity / 1024 / 1024 / 1024)

		if ($module.MemoryType -ne 0) {
			# Only MemoryType is supported on < Win10
			$t = $module.MemoryType
		}
		elseif ($memory.SMBIOSMemoryType -ne 0) {
			# DDR4 and newer uses SMBIOSMemoryType instead of MemoryType
			$t = $memory.SMBIOSMemoryType
		}
		else {
			$t = 0
		}
		Switch ($t) {
			20 { $mem_type = 'DDR' }
			21 { $mem_type = 'DDR2' }
			22 { $mem_type = 'DDR2' }
			24 { $mem_type = 'DDR3' }
			26 { $mem_type = 'DDR4' }
			27 { $mem_type = 'DDR' }
			28 { $mem_type = 'DDR2' }
			29 { $mem_type = 'DDR3' }
			30 { $mem_type = 'DDR4' }
			34 { $mem_type = 'DDR5' }
			default { $mem_type = 'Unknown' }
		}

		switch ($module.FormFactor) {
			8 { $mem_type += ' DIMM' }
			12 { $mem_type += ' SODIMM' }
			default { $mem_type += ' Unknown' }
		}

		if ($module.DataWidth -ne $module.TotalWidth) {
			$mem_type += " (ECC)"
		}

		$mem_total += $mem_capacity
		$mem_label = "$($mem_capacity) GB $($module.PartNumber.trim())"
		$data.mem_type = $mem_type
		$data.mem_speed = $module.Speed
	}

	if ($module_counts.ContainsKey($mem_label)) {
		$module_counts[$mem_label] += 1
	} else {
		$module_counts[$mem_label] = 1
	}
}
$data.mem_size = $mem_total
$mem_models = @()
foreach ($key in $module_counts.Keys) {
	$mem_models += "$($module_counts[$key])x $key"
}
$data.mem_model = $mem_models -join ', '

# Process IP addresses
$ip_pri = $False
$ip_sec = $False
foreach ($addr in $Address) {
	if ($ip_pri -eq $False) {
		$data.ip_primary = $addr.IPAddress[0]
		$data.mac_primary = $addr.MACAddress
		$ip_pri = $True
	}
	elseif ($ip_sec -eq $False) {
		$data.ip_secondary = $addr.IPAddress[0]
		$data.mac_secondary = $addr.MACAddress
		$ip_sec = $True
	}
}

Write-Output $data | ConvertTo-Json

# Upload this data to the middleware application
$data_header = @{
	'Content-Type' = 'application/json'
	'X-Token' = $crm_client_id
}
$data_url = "$crm_url/scripts/device_inventory"
$data_body = $data | ConvertTo-Json

Try {
	Invoke-RestMethod -Uri $data_url -Method Post -Header $data_header -Body $data_body
}
Catch {
	Write-Error $_.Exception.Message
	$streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
	$ErrResp = $streamReader.ReadToEnd()
	$streamReader.Close()
	Write-Error $ErrResp
	exit(1)
}
