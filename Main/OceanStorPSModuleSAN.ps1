function get-DMluns{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Luns

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Luns

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage luns in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMluns -webSession $session

		OR

		PS C:\> $luns = get-DMluns

	.NOTES
		Filename: OceanstorPSModuleSAN.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
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

	$result = $storageLuns

	return $result
}

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
		Filename: OceanstorPSModuleSAN.ps1
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


function get-DMlunGroups{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Lun Groups

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Lun Groups

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage Lun Groups in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMlunGroups -webSession $session

		OR

		PS C:\> $lunGroups = get-DMlunGroups

	.NOTES
		Filename: OceanstorPSModuleSAN.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lungroup" | Select-Object -ExpandProperty data
    $lunGroups = New-Object System.Collections.ArrayList

	foreach ($lgroup in $response)
	{
		$lunGroup = [OceanStorLunGroup]::new($lgroup)
		$lunGroups += $lunGroup
	}

	$result = $lunGroups

	return $result
}

function get-DMhosts{
		<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage configured Hosts

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage configured Hosts

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage configured Hosts in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMhosts -webSession $session

		OR

		PS C:\> $hosts = get-DMhosts

	.NOTES
		Filename: OceanstorPSModuleSAN.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host" | Select-Object -ExpandProperty data
    $hosts = New-Object System.Collections.ArrayList

	foreach ($thost in $response)
	{
		$hostobj = [OceanStorHost]::new($thost)
		$hosts += $hostobj
	}

	$result = $hosts

	return $result
}

function get-DMhostGroups{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Host Groups

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Host Groups

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage Host Groups in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMhostGroups -webSession $session

		OR

		PS C:\> $hostGroups = get-DMhostGroups

	.NOTES
		Filename: OceanstorPSModuleSAN.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "hostgroup" | Select-Object -ExpandProperty data
    $hostgroups = New-Object System.Collections.ArrayList

	foreach ($hgroup in $response)
	{
		$hostgroup = [OceanStorHostGroup]::new($hgroup)
		$hostgroups += $hostgroup
	}

	$result = $hostgroups

	return $result
}

