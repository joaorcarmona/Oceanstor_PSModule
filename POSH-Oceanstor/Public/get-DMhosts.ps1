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
    Filename: get-DMhosts.ps1
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