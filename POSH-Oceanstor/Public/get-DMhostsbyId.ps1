function get-DMhostsbyId{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts querying by Hostid

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.PARAMETER HostId
		Mandatory parameter [string], to set the Host ID to look for.

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage configured Hosts in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMhostsbyId -webSession $session -hostId 1

    OR

    PS C:\> $hosts = get-DMhostsbyId -hostId 1

.NOTES
    Filename: get-DMhostsbyId.ps1
    Author: Joao Carmona
    Modified date: 2022-05-27
    Version 0.1

.LINK
#>
[Cmdletbinding()]
Param(
[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
    [pscustomobject]$WebSession,
[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
    [string]$hostId
)

if ($WebSession){
    $session = $WebSession
} else {
    $session = $deviceManager
}

$response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host?filter=ID:$hostId" | Select-Object -ExpandProperty data
$hosts = New-Object System.Collections.ArrayList

foreach ($thost in $response)
{
    $hostobj = [OceanStorHost]::new($thost)
    $hosts += $hostobj
}

$result = $hosts

return $result
}