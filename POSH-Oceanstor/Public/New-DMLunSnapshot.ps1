function New-DMLunSnapshot {
    <#
    .SYNOPSIS
        Creates a snapshot of a Huawei OceanStor LUN.

    .DESCRIPTION
        Creates a LUN snapshot through the OceanStor snapshot REST resource.

    .PARAMETER WebSession
        Optional session for the REST call. If omitted, the deviceManager
        global variable is used.

    .PARAMETER SnapshotName
        Name of the snapshot to create.

    .PARAMETER SourceLunName
        Name of the source LUN. Valid values are checked against Get-DMluns
        and support tab completion. The selected LUN ID is sent to the API.

    .PARAMETER Description
        Optional description of the snapshot.

    .PARAMETER ReadOnly
        Optional switch to request a read-only snapshot.

    .OUTPUTS
        OceanstorLunSnapshot when creation succeeds, otherwise the REST error.

    .EXAMPLE
        PS C:\> New-DMLunSnapshot -SnapshotName 'db-before-patch' -SourceLunName 'production-db'

    .EXAMPLE
        PS C:\> New-DMLunSnapshot -WebSession $session -SnapshotName 'db-readonly' -SourceLunName 'production-db' -ReadOnly
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SnapshotName,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 2)]
        [ValidateScript({
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $deviceManager
                }

                $luns = Get-DMluns -WebSession $session
                $matchingLuns = @($luns | Where-Object Name -EQ $_)

                if ($matchingLuns.Count -eq 1) {
                    $true
                }
                elseif ($matchingLuns.Count -gt 1) {
                    throw "SourceLunName is ambiguous because more than one LUN is named '$_'."
                }
                else {
                    throw "Invalid SourceLunName. Valid values are: $($luns.Name -join ', ')"
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

                if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $session = $fakeBoundParameters.WebSession
                }
                else {
                    $session = $deviceManager
                }

                (Get-DMluns -WebSession $session).Name |
                    Sort-Object -Unique |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SourceLunName,

        [Parameter(Position = 3)]
        [string]$Description,

        [Parameter(Position = 4)]
        [switch]$ReadOnly
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $sourceLun = @(Get-DMluns -WebSession $session | Where-Object Name -EQ $SourceLunName)[0]

    $body = @{
        TYPE       = 27
        PARENTTYPE = 11
        PARENTID   = $sourceLun.Id
    }

    if ($SnapshotName) {
        $body.Add('NAME', $SnapshotName)
    }
    else {
        $body.Add('NAME', "snap_$($SourceLunName)-$(Get-Date -Format 'yyyyMMddHHmmss')")
    }

    if ($Description) {
        $body.Add('DESCRIPTION', $Description)
    }

    if ($ReadOnly) {
        $body.Add('isReadOnly', $true)
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot' -BodyData $body

    if ($response.error.Code -eq 0) {
        return [OceanstorLunSnapshot]::new($response.data, $session)
    }

    return $response.error
}
