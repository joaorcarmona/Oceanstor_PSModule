function Get-DMhostbyId {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts querying by Hostid

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.PARAMETER HostId
		Mandatory parameter [string], to set the Host ID to look for.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession and provide hostId by property name.

.OUTPUTS
    OceanStorHost

    Returns host objects whose ID matches the supplied hostId value.

.EXAMPLE

    PS C:\> Get-DMhostbyId -webSession $session -hostId 1

    OR

    PS C:\> $hosts = Get-DMhostbyId -hostId 1

.NOTES
    Filename: Get-DMhostbyId.ps1

.LINK
#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [string]$hostId
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

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host?filter=ID:$([uri]::EscapeDataString($hostId))" | Select-DMResponseData
    $hosts = New-Object System.Collections.ArrayList

    foreach ($thost in $response) {
        $hostobj = [OceanStorHost]::new($thost, $session)
        [void]$hosts.Add($hostobj)
    }

    $hosts = @(Set-DMHostInitiator -InputObject $hosts -WebSession $session)

    $hosts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $hosts

    return $result
}

Set-Alias -Name Get-DMhostsbyId -Value Get-DMhostbyId
