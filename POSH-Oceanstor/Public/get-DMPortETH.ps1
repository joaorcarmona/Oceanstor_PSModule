function get-DMPortETH{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Ethernet Ports

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Ethernet Ports

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage configured Ethernet Ports in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMPortETH -webSession $session

    OR

    PS C:\> $ethPorts = get-DMPortETH

.NOTES
    Filename: get-DMPortETH.ps1
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

$response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "eth_port" | Select-Object -ExpandProperty data
$ethPorts = New-Object System.Collections.ArrayList

foreach ($peth in $response)
{
    $ethpObj = [OceanStorPortETH]::new($peth)
    $ethPorts += $ethpObj
}

$result = $ethPorts

return $result
}