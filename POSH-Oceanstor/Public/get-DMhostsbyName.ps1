function get-DMhostsbyName{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts querying by Host Name

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.PARAMETER Name
		Mandatory parameter [string], to set the Host Name to look for.

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage configured Hosts in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMhostsbyName -webSession $session -Name Host001

    OR

    PS C:\> $hosts = get-DMhostsbyName -Name Host001

.NOTES
    Filename: get-DMhostsbyName.ps1
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
    [string]$Name
)

if ($WebSession){
    $session = $WebSession
} else {
    $session = $deviceManager
}

$response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host?filter=NAME:$Name" | Select-Object -ExpandProperty data
$hosts = New-Object System.Collections.ArrayList

foreach ($thost in $response)
{
    $hostobj = [OceanStorHost]::new($thost)
    $hosts += $hostobj
}

$result = $hosts

return $result
}