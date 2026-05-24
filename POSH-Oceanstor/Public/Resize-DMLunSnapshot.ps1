function Resize-DMLunSnapshot {
    <#
    .SYNOPSIS
        Expands a Huawei OceanStor LUN snapshot.

    .DESCRIPTION
        Resolves a snapshot name to its ID and sets its user capacity through
        the OceanStor snapshot REST resource.

    .PARAMETER WebSession
        Optional session for the REST call. If omitted, the deviceManager
        global variable is used.

    .PARAMETER SnapShotName
        Name of the snapshot to expand. Valid values are checked against
        get-DMLunSnapshots and support tab completion.

    .PARAMETER UserCapacity
        New snapshot user capacity in sectors, as required by the REST API.

    .OUTPUTS
        REST error status returned by the storage system.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [ValidateScript({
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $deviceManager
                }

                $snapshots = @(get-DMLunSnapshots -WebSession $session)
                $matchingSnapshots = @($snapshots | Where-Object Name -EQ $_)

                if ($matchingSnapshots.Count -eq 1) {
                    $true
                }
                elseif ($matchingSnapshots.Count -gt 1) {
                    throw "SnapShotName is ambiguous because more than one snapshot is named '$_'."
                }
                else {
                    throw "Invalid SnapShotName. Valid values are: $($snapshots.Name -join ', ')"
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

                (get-DMLunSnapshots -WebSession $session).Name |
                    Sort-Object -Unique |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SnapShotName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateRange(1, [uint64]::MaxValue)]
        [uint64]$UserCapacity
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $snapshot = @(get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $SnapShotName)[0]

    if ($null -ne $snapshot.'User Capacity' -and $UserCapacity -le [uint64]$snapshot.'User Capacity') {
        throw "UserCapacity must be greater than the current snapshot capacity of $($snapshot.'User Capacity') sectors."
    }

    if ($PSCmdlet.ShouldProcess($SnapShotName, 'Expand LUN snapshot')) {
        $body = @{
            ID           = $snapshot.Id
            USERCAPACITY = $UserCapacity
        }
        $response = invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snapshot/expand' -BodyData $body
        return $response.error
    }
}
