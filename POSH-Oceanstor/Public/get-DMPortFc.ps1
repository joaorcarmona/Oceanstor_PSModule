function get-DMPortFc{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured FC Ports

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured FC Ports

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage configured FC Ports in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMPortFc -webSession $session

    OR

    PS C:\> $fcPorts = get-DMPortFc

.NOTES
    Filename: get-DMPortFc.ps1
    Author: Joao Carmona
    Modified date: 2022-06-23
    Version 0.1

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

$response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "fc_port" | Select-Object -ExpandProperty data
$fcPorts = New-Object System.Collections.ArrayList

foreach ($pfc in $response)
{
    $fcpObj = [OceanStorPortFC]::new($pfc)
    $fcPorts += $fcpObj
}

$result = $fcPorts

return $result
}