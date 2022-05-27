function get-DMhostsbyHostGroupName{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts querying by HostGroupName

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts querying by HostGroupName

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.PARAMETER HostGroupName
		Mandatory parameter [string], to set the HostGroupName to look for.

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage configured Hosts in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMhostsbyHostGroupName -webSession $session -HostGroupName 10

    OR

    PS C:\> $hosts = get-DMhostsbyHostGroupName -HostGroupName 10

.NOTES
    Filename: get-DMhostsbyHostGroupName.ps1
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
    [string]$HostGroupName
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

$result = $hosts | Where-Object "HostGroup Name" -Match $HostGroupName

return $result
}