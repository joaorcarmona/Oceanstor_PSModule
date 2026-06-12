function Get-DMhostsbyName {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts querying by Host Name

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.PARAMETER Name
		Mandatory parameter [string], to set the Host Name to look for.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession and provide Name by property name.

.OUTPUTS
    OceanStorHost

    Returns host objects whose name matches the supplied Name value.

.EXAMPLE

    PS C:\> Get-DMhostsbyName -webSession $session -Name Host001

    OR

    PS C:\> $hosts = Get-DMhostsbyName -Name Host001

.NOTES
    Filename: Get-DMhostsbyName.ps1

.LINK
#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [string]$Name
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

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host?filter=NAME:$Name" | Select-Object -ExpandProperty data
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
