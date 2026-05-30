function Get-DMInterfaceModules {
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

    PS C:\> Get-DMInterfaceModules -webSession $session

    OR

    PS C:\> $controllers = Get-DMInterfaceModules

.NOTES
    Filename: Get-DMInterfaceModules.ps1
    Author: Joao Carmona
    Modified date: 2022-06-02
    Version 0.1

.LINK
#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Model"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "intf_module" | Select-Object -ExpandProperty data
    $interfaceModules = New-Object System.Collections.ArrayList

    foreach ($imodule in $response) {
        $interfaceModule = [OceanstorInterfaceModule]::new($imodule, $session)
        [void]$interfaceModules.Add($interfaceModule)
    }

    $interfaceModules | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $interfaceModules

    return $result
}
