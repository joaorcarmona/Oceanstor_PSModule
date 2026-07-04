<#
.SYNOPSIS
    Expands an OceanStor LUN snapshot.

.DESCRIPTION
    Resolves a snapshot name or Id to its ID and sets its user capacity through the OceanStor snapshot REST resource.
    UserCapacity must be greater than the current snapshot capacity. The cmdlet supports -WhatIf and -Confirm.
    The snapshot can be identified by Name or by Id; Name and Id are mutually exclusive, enforced by PowerShell
    parameter sets. SnapShotName is validated at parameter-binding time with tab completion; SnapShotId is
    validated too, but has no tab completion.

    Accepts multiple snapshots from the pipeline by property name. Each is expanded independently: a
    failure (e.g. an invalid/ambiguous name, or a REST error) is reported as a non-terminating error and
    does not stop the remaining snapshots from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SnapShotName
    Name of the snapshot to expand. Valid values are checked against Get-DMLunSnapshot and support tab completion. Mutually exclusive with SnapShotId.

.PARAMETER SnapShotId
    Id of the snapshot to expand. Valid values are checked against Get-DMLunSnapshot, no tab completion. Mutually exclusive with SnapShotName.

.PARAMETER UserCapacity
    New snapshot user capacity in sectors, as required by the REST API.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Resize-DMLunSnapshot -SnapShotName 'snap_lun01_before_patch' -UserCapacity 2147483648 -WhatIf

    Shows what would happen if the LUN snapshot capacity were expanded.

.EXAMPLE
    PS> Get-DMLunSnapshot -Id 5 | Resize-DMLunSnapshot -UserCapacity 2147483648

    Expands the piped snapshot.

.NOTES
    Filename: Resize-DMLunSnapshot.ps1
#>
function Resize-DMLunSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('Name')]
        [ValidateScript({
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $script:CurrentOceanstorSession
                }

                $matchingSnapshots = @(Get-DMLunSnapshot -WebSession $session -Name $_ | Where-Object Name -EQ $_)

                if ($matchingSnapshots.Count -eq 1) {
                    $true
                }
                elseif ($matchingSnapshots.Count -gt 1) {
                    throw "SnapShotName is ambiguous because more than one snapshot is named '$_'."
                }
                else {
                    throw 'Invalid SnapShotName.'
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

                (Get-DMLunSnapshot -WebSession $session).Name |
                    Sort-Object -Unique |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SnapShotName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMLunSnapshot -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                throw 'Invalid SnapShotId.'
            })]
        [string]$SnapShotId,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, [uint64]::MaxValue)]
        [uint64]$UserCapacity
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $snapshot = @(Get-DMLunSnapshot -WebSession $session -Id $SnapShotId)[0]
                if ($null -eq $snapshot) { throw "Could not resolve 'SnapShotId' - the object may have been removed since parameter validation." }
            }
            else {
                $snapshot = @(Get-DMLunSnapshot -WebSession $session -Name $SnapShotName | Where-Object Name -EQ $SnapShotName)[0]
                if ($null -eq $snapshot) { throw "Could not resolve 'SnapShotName' - the object may have been removed since parameter validation." }
            }

            if ($null -ne $snapshot.'User Capacity' -and $UserCapacity -le [uint64]$snapshot.'User Capacity') {
                throw "UserCapacity must be greater than the current snapshot capacity of $($snapshot.'User Capacity') sectors."
            }

            if ($PSCmdlet.ShouldProcess($snapshot.Name, 'Expand LUN snapshot')) {
                $body = @{
                    ID           = $snapshot.Id
                    USERCAPACITY = $UserCapacity
                }
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snapshot/expand' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
