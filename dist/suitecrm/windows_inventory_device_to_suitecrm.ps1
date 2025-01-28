<#
.TITLE
	Collect Asset Inventory (SuiteCRM) [Windows]

.DESCRIPTION
	Collect asset information for a device including CPU, memory, network, and OS details.
	This information is then sent to SuiteCRM for asset tracking.

.SUPPORTS
	Windows 10, 11

.CATEGORY
	Asset Tracking

.LICENSE
	AGPLv3

.TRMM ENVIRONMENT
	CRM_URL={{client.crm_url}}
	CRM_CLIENT_ID={{client.crm_client_id}}
	CRM_CLIENT_SECRET={{client.crm_client_secret}}
#>

$crm_url = $Env:CRM_URL
$crm_client_id = $Env:CRM_CLIENT_ID
$crm_client_secret = $Env:CRM_CLIENT_SECRET
$crm_object = 'MSP_Devices'

if ($crm_url -eq $null -or $crm_url -eq '') {
	Write-Host "CRM_URL is not set"
	exit(1)
}

if ($crm_client_id -eq $null -or $crm_client_id -eq '') {
	Write-Host "CRM_CLIENT_ID is not set"
	exit(1)
}

if ($crm_client_secret -eq $null -or $crm_client_secret -eq '') {
	Write-Host "CRM_CLIENT_SECRET is not set"
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
$data.name = $ComputerSystem.Name
if ($ComputerSystem.Domain -ne $null) {
	$data.name += '.' + $ComputerSystem.Domain
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
			20 { $mem_type = 'ddr' }
			21 { $mem_type = 'ddr2' }
			22 { $mem_type = 'ddr2' }
			24 { $mem_type = 'ddr3' }
			26 { $mem_type = 'ddr4' }
			27 { $mem_type = 'ddr' }
			28 { $mem_type = 'ddr2' }
			29 { $mem_type = 'ddr3' }
			30 { $mem_type = 'ddr4' }
			34 { $mem_type = 'ddr5' }
			default { $mem_type = 'unknown' }
		}

		switch ($module.FormFactor) {
			8 { $mem_type += '_dimm' }
			12 { $mem_type += '_sodimm' }
			default { $mem_type += '_unknown' }
		}

		if ($module.DataWidth -ne $module.TotalWidth) {
			$mem_type += "_ecc"
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
		$data.ip_pri = $addr.IPAddress[0]
		$data.mac_pri = $addr.MACAddress
		$ip_pri = $True
	}
	elseif ($ip_sec -eq $False) {
		$data.ip_sec = $addr.IPAddress[0]
		$data.mac_sec = $addr.MACAddress
		$ip_sec = $True
	}
}

Write-Output $data | ConvertTo-Json

# Request an access token via OAuth2 from SuitCRM
$token_url = "https://$crm_url/Api/access_token"
$token_body = @{
	grant_type = 'client_credentials'
	client_id = $crm_client_id
	client_secret = $crm_client_secret
}
Try {
	$token_response = Invoke-RestMethod -Uri $token_url -Method Post -Body $token_body
}
Catch {
	Write-Host $_.Exception.Message
	$streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
	$ErrResp = $streamReader.ReadToEnd()
	$streamReader.Close()
	Write-Host $ErrResp
	exit(1)
}
$access_token = $token_response.access_token


# Locate the device ID based on its mac
$data_url = "https://$crm_url/Api/V8/module/MSP_Devices?fields[MSP_Devices]=id&filter[operator]=OR&filter[mac_pri][EQ]=$($data.mac_pri)&filter[mac_sec][EQ]=$($data.mac_pri)"
$data_header = @{
	'Content-Type' = 'application/json'
	'Accept' = 'application/json'
	'Authorization' = 'Bearer ' + $access_token
}
Try {
	$find_response = Invoke-RestMethod -Uri $data_url -Method Get -Header $data_header
}
Catch {
	Write-Host $_.Exception.Message
	$streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
	$ErrResp = $streamReader.ReadToEnd()
	$streamReader.Close()
	Write-Host $ErrResp
	exit(1)
}

if ($find_response.data.Count -eq 0) {
	# Device does not exist; create new.
	$data_method = 'Post'
	$data_body = @{
		'data' = @{
			'type' = $crm_object
			'attributes' = $data
		}
	} | ConvertTo-Json
}
else {
	# Device exists, send an update request
	$data_method = 'Patch'
	$data_body = @{
		'data' = @{
			'type' = $crm_object
			'id' = $find_response.data[0].id
			'attributes' = $data
		}
	} | ConvertTo-Json
}

# Send the device data to SuiteCRM
$data_url = "https://$crm_url/Api/V8/module"
$data_header = @{
	'Content-Type' = 'application/json'
	'Accept' = 'application/json'
	'Authorization' = 'Bearer ' + $access_token
}
Try {
	Invoke-RestMethod -Uri $data_url -Method $data_method -Header $data_header -Body $data_body
}
Catch {
	Write-Host $_.Exception.Message
	$streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
	$ErrResp = $streamReader.ReadToEnd()
	$streamReader.Close()
	Write-Host $ErrResp
	exit(1)
}

