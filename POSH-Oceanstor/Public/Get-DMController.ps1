function Get-DMController {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage Controller

.DESCRIPTION
    Function to request Huawei Oceanstor Controller in the system

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanStorController

    Returns controller objects.

.EXAMPLE

    PS C:\> Get-DMController -webSession $session

    OR

    PS C:\> $controllers = Get-DMController

.NOTES
    Filename: Get-DMController.ps1

.LINK
#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Location", "Health Status", "Running Status", "Is Master"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "controller" | Select-DMResponseData
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

Set-Alias -Name Get-DMControllers -Value Get-DMController
