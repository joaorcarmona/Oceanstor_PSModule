function Set-DMPerformanceMonitoring {
    <#
    .SYNOPSIS
        Updates the OceanStor performance-monitoring sampling/archive strategy.

    .DESCRIPTION
        Updates the performance_statistic_strategy resource. Only the parameters actually
        specified by the caller are sent in the PUT body (partial update).

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER SamplingIntervalSeconds
        Realtime sampling interval, in seconds.

    .PARAMETER ArchiveIntervalSeconds
        Historical-archive sampling interval, in seconds.

    .PARAMETER EnableArchive
        Whether historical performance archiving is enabled.

    .PARAMETER AutoStop
        Whether performance statistics collection stops automatically.

    .PARAMETER MaxDays
        Maximum number of days of archived performance data to retain.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Set-DMPerformanceMonitoring -SamplingIntervalSeconds 30

    .NOTES
        Filename: Set-DMPerformanceMonitoring.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $false)]
        [ValidateSet(5, 10, 30, 60)]
        [int]$SamplingIntervalSeconds,

        [Parameter(Mandatory = $false)]
        [ValidateSet(5, 60, 120, 300, 600, 1800, 3600)]
        [int]$ArchiveIntervalSeconds,

        [Parameter(Mandatory = $false)]
        [bool]$EnableArchive,

        [Parameter(Mandatory = $false)]
        [bool]$AutoStop,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 3650)]
        [int]$MaxDays
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $body = @{}
            if ($PSBoundParameters.ContainsKey('SamplingIntervalSeconds')) { $body.CMO_STATISTIC_INTERVAL = $SamplingIntervalSeconds }
            if ($PSBoundParameters.ContainsKey('ArchiveIntervalSeconds')) { $body.CMO_STATISTIC_ARCHIVE_TIME = $ArchiveIntervalSeconds }
            if ($PSBoundParameters.ContainsKey('EnableArchive')) { $body.CMO_STATISTIC_ARCHIVE_SWITCH = [int]$EnableArchive }
            if ($PSBoundParameters.ContainsKey('AutoStop')) { $body.CMO_STATISTIC_AUTO_STOP = [int]$AutoStop }
            if ($PSBoundParameters.ContainsKey('MaxDays')) { $body.CMO_STATISTIC_MAX_TIME = $MaxDays }

            if ($body.Count -eq 0) {
                Write-Warning 'No parameters were specified; nothing to update.'
                return
            }

            if ($PSCmdlet.ShouldProcess('OceanStor', 'Update performance monitoring strategy')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'performance_statistic_strategy' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
