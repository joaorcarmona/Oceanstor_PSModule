function Get-DMhostbyName {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts querying by Host Name

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.PARAMETER Name
		Mandatory parameter [string], to set the Host Name to look for.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession and provide Name by property name.

.OUTPUTS
    OceanStorHost

    Returns host objects whose name matches the supplied Name value.

.EXAMPLE

    PS C:\> Get-DMhostbyName -webSession $session -Name Host001

    OR

    PS C:\> $hosts = Get-DMhostbyName -Name Host001

.NOTES
    Filename: Get-DMhostbyName.ps1

.LINK
#>
    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [string]$Name
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Operation System", "Parent Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host?filter=NAME:$([uri]::EscapeDataString($Name))" | Select-DMResponseData
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

Set-Alias -Name Get-DMhostsbyName -Value Get-DMhostbyName
