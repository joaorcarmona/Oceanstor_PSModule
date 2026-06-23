function Get-DMhostbyHostGroupName {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts querying by HostGroupName

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts querying by HostGroupName

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.PARAMETER HostGroupName
		Mandatory parameter [string], to set the HostGroupName to look for.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession and provide HostGroupName by property name.

.OUTPUTS
    OceanStorHost

    Returns host objects whose Parent Name matches the supplied HostGroupName value.

.EXAMPLE

    PS C:\> Get-DMhostbyHostGroupName -webSession $session -HostGroupName 10

    OR

    PS C:\> $hosts = Get-DMhostbyHostGroupName -HostGroupName 10

.NOTES
    Filename: Get-DMhostbyHostGroupName.ps1

.LINK
#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [string]$HostGroupName
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

    $result = $hosts | Where-Object "Parent Name" -Match $HostGroupName

    $result = @(Set-DMHostInitiators -InputObject $result -WebSession $session)

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMhostsbyHostGroupName -Value Get-DMhostbyHostGroupName
