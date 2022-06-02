function get-DMControllers{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage Controller

.DESCRIPTION
    Function to request Huawei Oceanstor Controller in the system

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage controller in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMControllers -webSession $session

    OR

    PS C:\> $controllers = get-DMControllers

.NOTES
    Filename: get-DMControllers.ps1
    Author: Joao Carmona
    Modified date: 2022-06-02
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

$response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "controller" | Select-Object -ExpandProperty data
$controllers = New-Object System.Collections.ArrayList

foreach ($tcont in $response)
{
    $controller = [OceanStorController]::new($tcont)
    $controllers += $controller
}

$result = $controllers

return $result
}