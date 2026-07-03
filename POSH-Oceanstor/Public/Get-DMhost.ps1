function Get-DMhost {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.PARAMETER Name
    Optional host name to search for, positional. When omitted, every host is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

.PARAMETER Id
    Optional host ID to search for. Mutually exclusive with Name (enforced by parameter set). Returns exactly one host, exact match only, no wildcard support.

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

    OR

    PS C:\> Get-DMhost 'esx01'

    OR

    PS C:\> Get-DMhost -Id '1'

.NOTES
    Filename: Get-DMhost.ps1

.LINK
#>
    [Cmdletbinding(DefaultParameterSetName = 'ByName')]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 1, Mandatory = $false)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [string]$VstoreId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        return @(Get-DMhostbyFilter -WebSession $session -Filter 'Id' -Keyword $Id)
    }

    if ($Name) {
        return @(Get-DMhostbyFilter -WebSession $session -Filter 'Name' -Keyword $Name)
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Operation System", "Parent Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = 'host'
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }
    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
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

Set-Alias -Name Get-DMhosts -Value Get-DMhost
