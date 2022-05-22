function get-DMlunsByWWN{
	<#
	.SYNOPSIS
		To Search for lun by lun WWN

	.DESCRIPTION
		Function to search for a lun based on lun WWN

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
	.PARAMETER wwn
		Mandatory parameter [string], to set the WWN to look for.

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage lun, my searching lun WWN. Return lun Object

	.EXAMPLE

		PS C:\> get-DMlunsByWWN -webSession $session -wwn "6a08cf810075766e1efc050700000005"

		OR

		PS C:\> $luns = get-DMlunsByWWN -wwn "6a08cf810075766e1efc050700000005"

	.NOTES
		Filename: get-DMlunsByWWN.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
        [pscustomobject]$wwn
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lun" | Select-Object -ExpandProperty data
    $StorageLuns = New-Object System.Collections.ArrayList

	foreach ($tlun in $response)
	{
		$lun = [OceanstorDeviceLun]::new($tlun)
		$StorageLuns += $lun
	}

	$result = $StorageLuns | Where-Object wwn -Match $wwn

	return $result
}