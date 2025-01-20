<#
.TITLE
    Get Windows License Information

.DESCRIPTION
    Collect the windows license key, product, and status.

.SUPPORTS
    Windows 8, 10, 11, Server 2016, Server 2019

.CATEGORY
    Licensing

.LICENSE
    AGPLv3

.OUTPUTS
   {
     "ProductType": "...",   # License type, usually Retail, OEM, etc
     "ProductId": "...",     # Product ID of this version of Windows
     "ProductName": "...",   # Human-friendly name of the version of Windows
     "ProductKey": "...",    # License key for this installation
     "ProductStatus": "...", # Status of the license, ie: Licensed, Unlicensed, etc
   }

#>

$SLP = $(Get-CimInstance SoftwareLicensingProduct -Filter 'PartialProductKey is not null' | ? name -like windows*)

$ProductType = $SLP.ProductKeyChannel
$ProductId = $SLP.ProductKeyID2
$LicenseStatus = $SLP.LicenseStatus
$ProductName = $(Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\').ProductName
$BiosKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey

# Parse product key (either simply from the BIOS or calculated)
if ($BiosKey -ne '') {
	$ProductKey = $BiosKey
}
else {
	# Decode product key from binary data found in the registry
	# https://github.com/mrpeardotnet/WinProdKeyFinder/blob/master/WinProdKeyFind/KeyDecoder.cs
	# Original code licensed under the MIT
	$DigitalProductId = $(Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\').DigitalProductId
	# Extracts out the product ID from the binary data, (this refers to the product, ie: Windows 11 Professional)
	$ProductID = $(Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\').ProductId

	$isWin8 = $DigitalProductId[66] / 6 -band 1
	$DigitalProductId[66] = ($DigitalProductId[66] -band 247) -bor (($isWin8 -band 2) * 4)
	$ProductKey = ''
	$Chars = 'BCDFGHJKMPQRTVWXY2346789'
	$Last = 0
	For ($i = 24; $i -ge 0; $i-=1) {
		$Cur = 0
		For ($j = 14; $j -ge 0; $j -= 1) {
			$Cur = $Cur * 256
			$Cur = $DigitalProductId[$j + 52] + $Cur
			$DigitalProductId[$j + 52] = [math]::Floor($Cur / 24)
			$Cur = $Cur % 24
			$Last = $Cur
		}
		$ProductKey = $Chars[$Cur] + $ProductKey
	}

	$Key1 = $ProductKey.Substring(1, $Last)
	$Key2 = $ProductKey.Substring($Last + 1, $ProductKey.Length - $Last - 1)
	$ProductKey = $Key1 + "N" + $Key2

	For ($i = 5; $i -lt $ProductKey.Length; $i += 6) {
		$ProductKey = $ProductKey.Insert($i, '-')
	}
}

# Parse license status
$Warn = $True
switch ($LicenseStatus) {
	0 { $LicenseStatus = 'Unlicensed' }
	1 { $LicenseStatus = 'Licensed'; $Warn = $False }
	2 { $LicenseStatus = 'Out-Of-Box Grace' }
	3 { $LicenseStatus = 'Out-Of-Tolerance Grace' }
	4 { $LicenseStatus = 'Non-Genuine Grace' }
	5 { $LicenseStatus = 'Notification' }
	6 { $LicenseStatus = 'Extended Grace' }
}

Write-Output @{
	ProductType = $ProductType
	ProductId = $ProductId
	ProductName = $ProductName
	ProductKey = $ProductKey
	ProductStatus = $LicenseStatus
} | ConvertTo-Json

if ($Warn) {
	# Set exit status to 1 if Windows is not licensed to notify calling script there was an issue.
	exit 1
}
