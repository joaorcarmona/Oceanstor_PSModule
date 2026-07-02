function Get-DMInterfaceModule {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage Interface Modules

.DESCRIPTION
    Function to request Huawei Oceanstor Modules in the system

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanstorInterfaceModule

    Returns interface module objects.

.EXAMPLE

    PS C:\> Get-DMInterfaceModule -webSession $session

    OR

    PS C:\> $controllers = Get-DMInterfaceModule

.NOTES
    Filename: Get-DMInterfaceModule.ps1

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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Model"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "intf_module" | Select-DMResponseData
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

Set-Alias -Name Get-DMInterfaceModules -Value Get-DMInterfaceModule
