function get-DMInterfaceModules{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage Interface Modules

.DESCRIPTION
    Function to request Huawei Oceanstor Modules in the system

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage Modules in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMInterfaceModules -webSession $session

    OR

    PS C:\> $controllers = get-DMInterfaceModules

.NOTES
    Filename: get-DMInterfaceModules.ps1
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

$response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "intf_module" | Select-Object -ExpandProperty data
$interfaceModules = New-Object System.Collections.ArrayList

foreach ($imodule in $response)
{
    $interfaceModule = [OceanstorInterfaceModule]::new($imodule)
    $interfaceModules += $interfaceModule
}

$result = $interfaceModules

return $result
}