<#
.SYNOPSIS
    Retrieves OceanStor LUN snapshots.

.DESCRIPTION
    Uses the OceanStor snapshot interface to retrieve LUN snapshots and maps each record to an OceanstorLunSnapshot object.
    With no arguments, returns every snapshot. A specific snapshot can be looked up by its own Name (wildcard-filtered)
    or Id. Results can also be filtered to snapshots for a specific source LUN via -LunName.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Optional snapshot name to search for, positional. Supports PowerShell wildcards (*, ?, [...]). Mutually exclusive with Id and LunName.

.PARAMETER Id
    Optional snapshot ID to search for. Returns exactly one snapshot, exact match only. Mutually exclusive with Name and LunName.

.PARAMETER LunName
    Optional name of the source LUN whose snapshots should be returned. Valid values are checked against Get-DMlun and support tab completion. Mutually exclusive with Name and Id.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorLunSnapshot

.EXAMPLE
    PS> Get-DMLunSnapshot -WebSession $session

    Returns all visible LUN snapshots using the supplied session.

.EXAMPLE
    PS> $snapshots = Get-DMLunSnapshot

    Stores all visible LUN snapshots using the module's cached $script:CurrentOceanstorSession session.

.EXAMPLE
    PS> Get-DMLunSnapshot 'db-before-patch'

    Returns the snapshot named db-before-patch.

.EXAMPLE
    PS> Get-DMLunSnapshot -Id 5

    Returns the snapshot with ID 5.

.EXAMPLE
    PS> Get-DMLunSnapshot -LunName 'production-db'

    Returns snapshots whose source LUN is production-db.

.NOTES
    Filename: Get-DMLunSnapshot.ps1
#>
function Get-DMLunSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'BySourceLun', ValueFromPipelineByPropertyName = $true)]
        [Alias('SourceLunName')]
        [ValidateScript({
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $script:CurrentOceanstorSession
                }

                $matchingLuns = @(Get-DMlun -WebSession $session -Name $_ | Where-Object Name -EQ $_)

                if ($matchingLuns.Count -eq 1) {
                    $true
                }
                elseif ($matchingLuns.Count -gt 1) {
                    throw "LunName is ambiguous because more than one LUN is named '$_'."
                }
                else {
                    throw 'Invalid LunName.'
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

                if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $session = $fakeBoundParameters.WebSession
                }
                else {
                    $session = $script:CurrentOceanstorSession
                }

                (Get-DMlun -WebSession $session).Name |
                    Sort-Object -Unique |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = 'Id', 'Name', 'Source Lun Name', 'Health Status', 'Running Status'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = 'snapshot'
    $sourceLun = $null

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        # Double colon requests an exact match; a single colon is a fuzzy substring
        # match on this API (confirmed live for hosts: filter=ID:5 matched every ID
        # containing "5"), which would leak unrelated snapshots.
        $resource = "snapshot?filter=ID::$Id"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByName' -and $Name) {
        $hasWildcard = $Name -match '[*?\[\]]'
        if (-not $hasWildcard) {
            $resource = "snapshot?filter=NAME::$([uri]::EscapeDataString($Name))"
        }
        elseif ($Name -match '^\*?([^*?\[\]]+)\*?$') {
            $resource = "snapshot?filter=NAME:$([uri]::EscapeDataString($Matches[1]))"
        }
    }
    elseif ($LunName) {
        $sourceLun = @(Get-DMlun -WebSession $session -Name $LunName | Where-Object Name -EQ $LunName)[0]
        if ($null -eq $sourceLun) { throw "Could not resolve 'sourceLun' — the object may have been removed since parameter validation." }
        $resource = "snapshot?filter=SOURCELUNID::$($sourceLun.Id)"
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    $snapshots = [System.Collections.ArrayList]::new()

    foreach ($snapshotData in @($response)) {
        $snapshot = [OceanstorLunSnapshot]::new($snapshotData, $session)
        if ($sourceLun -and $snapshot.'Source Lun Id' -ne $sourceLun.Id) {
            continue
        }
        if ($PSCmdlet.ParameterSetName -eq 'ById' -and $snapshot.Id -ne $Id) {
            continue
        }
        if ($PSCmdlet.ParameterSetName -eq 'ByName' -and $Name -and $snapshot.Name -notlike $Name) {
            continue
        }
        $snapshot | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        [void]$snapshots.Add($snapshot)
    }

    return $snapshots
}

Set-Alias -Name Get-DMLunSnapshots -Value Get-DMLunSnapshot
