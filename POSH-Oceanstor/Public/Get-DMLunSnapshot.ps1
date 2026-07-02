<#
.SYNOPSIS
    Retrieves OceanStor LUN snapshots.

.DESCRIPTION
    Uses the OceanStor snapshot interface to retrieve LUN snapshots and maps each record to an OceanstorLunSnapshot object.
    Results can be filtered to snapshots for a specific source LUN.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER LunName
    Optional name of the source LUN whose snapshots should be returned. Valid values are checked against Get-DMlun and support tab completion.

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
    PS> Get-DMLunSnapshot -LunName 'production-db'

    Returns snapshots whose source LUN is production-db.

.NOTES
    Filename: Get-DMLunSnapshot.ps1
#>
function Get-DMLunSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('SourceLunName')]
        [ValidateScript({
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $script:CurrentOceanstorSession
                }

                $luns = Get-DMlun -WebSession $session
                $matchingLuns = @($luns | Where-Object Name -EQ $_)

                if ($matchingLuns.Count -eq 1) {
                    $true
                }
                elseif ($matchingLuns.Count -gt 1) {
                    throw "LunName is ambiguous because more than one LUN is named '$_'."
                }
                else {
                    throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
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
    if ($LunName) {
        $sourceLun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $LunName)[0]
        if ($null -eq $sourceLun) { throw "Could not resolve 'sourceLun' — the object may have been removed since parameter validation." }
        # Double colon requests an exact match; a single colon is a fuzzy substring
        # match on this API (confirmed live for hosts: filter=ID:5 matched every ID
        # containing "5"), which would leak snapshots from other LUNs whose Id
        # happens to contain this one's Id as a substring.
        $resource = "snapshot?filter=SOURCELUNID::$($sourceLun.Id)"
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    $snapshots = [System.Collections.ArrayList]::new()

    foreach ($snapshotData in @($response)) {
        $snapshot = [OceanstorLunSnapshot]::new($snapshotData, $session)
        if ($LunName -and $snapshot.'Source Lun Id' -ne $sourceLun.Id) {
            continue
        }
        $snapshot | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        [void]$snapshots.Add($snapshot)
    }

    return $snapshots
}

Set-Alias -Name Get-DMLunSnapshots -Value Get-DMLunSnapshot
