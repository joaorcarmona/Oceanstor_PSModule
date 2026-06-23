function Get-DMhost {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanStorHost

    Returns host objects.

.EXAMPLE

    PS C:\> Get-DMhost -webSession $session

    OR

    PS C:\> $hosts = Get-DMhost

.NOTES
    Filename: Get-DMhost.ps1

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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Operation System", "Parent Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host" | Select-Object -ExpandProperty data
    $hosts = New-Object System.Collections.ArrayList

    foreach ($thost in $response) {
        $hostobj = [OceanStorHost]::new($thost, $session)
        [void]$hosts.Add($hostobj)
    }

    $hosts = @(Set-DMHostInitiators -InputObject $hosts -WebSession $session)

    $hosts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $hosts

    return $result
}

Set-Alias -Name Get-DMhosts -Value Get-DMhost
