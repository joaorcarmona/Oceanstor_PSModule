function get-DMLunsbyFilter{
	<#
	.SYNOPSIS
		To Search for lun by lun WWN

	.DESCRIPTION
		Function to search for a lun based on lun WWN

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
	.PARAMETER filter
		Mandatory parameter [string], to be used as filter in the query. Needs to be a valid property name for the lun Object.
    .PARAMETER filter
        Mandatory parameter [string], to be used as keyword to search for luns. No need explicit wildcard (*), because it's implicit

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage lun, by applying a input filter and a keyword

	.EXAMPLE

		PS C:\> get-DMLunsbyFilter -webSession $session -Filter wwn -keyword "6a08cf810075766e1efc050700000005"

		OR

		PS C:\> $luns = get-DMLunsbyFilter -Filter wwn -keyword "6a08cf810075766e1efc050700000005"

	.NOTES
		Filename: get-DMLunsbyFilter.ps1
		Author: Joao Carmona
		Modified date: 2022-06-28
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=1,Mandatory=$true)]
        [pscustomobject]$filter,
    [Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$true)]
        [pscustomobject]$keyword
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lun" | Select-Object -ExpandProperty data
    $StorageLuns = New-Object System.Collections.ArrayList

	$StorageVersion = $session.version.Substring(0,2)

	if ($storageVersion -eq "V6")
	{
		$LunObjectClass = "OceanstorLunv6"
	} else {
		$LunObjectClass = "OceanstorLunv3"
	}

	foreach ($tlun in $response)
	{
		$lun = New-Object -TypeName $LunObjectClass -ArgumentList $tlun,$session
		#$lun = [OceanstorLun]::new($tlun,$session)
		$StorageLuns += $lun
	}

	$result = $StorageLuns | Where-Object $filter -Match $keyword

	return $result
}