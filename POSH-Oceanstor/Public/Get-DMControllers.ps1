function Get-DMControllers {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage Controller

.DESCRIPTION
    Function to request Huawei Oceanstor Controller in the system

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanStorController

    Returns controller objects.

.EXAMPLE

    PS C:\> Get-DMControllers -webSession $session

    OR

    PS C:\> $controllers = Get-DMControllers

.NOTES
    Filename: Get-DMControllers.ps1
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

    $defaultDisplaySet = "Id", "Location", "Health Status", "Running Status", "Is Master"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "controller" | Select-Object -ExpandProperty data
    $controllers = New-Object System.Collections.ArrayList

    foreach ($tcont in $response) {
        $controller = [OceanStorController]::new($tcont, $session)
        [void]$controllers.Add($controller)
    }

    $controllers | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $controllers

    return $result
}
