function get-DMhostsbyHostGroupId{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts querying by HostGroupId

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts querying by HostGroupId

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.PARAMETER HostGroupId
		Mandatory parameter [string], to set the HostGroup ID to look for.

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage configured Hosts in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMhostsbyHostGroupId -webSession $session -HostGroupId 10

    OR

    PS C:\> $hosts = get-DMhostsbyHostGroupId -HostGroupId 10

.NOTES
    Filename: get-DMhostsbyHostGroupId.ps1
    Author: Joao Carmona
    Modified date: 2022-05-27
    Version 0.1

.LINK
#>
[Cmdletbinding()]
Param(
[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
    [pscustomobject]$WebSession,
[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
    [string]$HostGroupId
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

$result = $hosts | Where-Object "HostGroup Id" -Match $HostGroupId

return $result
}