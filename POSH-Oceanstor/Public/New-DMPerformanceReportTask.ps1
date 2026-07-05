function New-DMPerformanceReportTask {
    <#
    .SYNOPSIS
        Creates an OceanStor performance report task for historical/ranged performance data.

    .DESCRIPTION
        Wraps the pms/report_task create interface (POST, v2 API). A report task defines what to
        collect -- a single object type/ID list/metric set, report_type 'performance' -- and over
        what time window. Running it (Invoke-DMPerformanceReportTask) generates a downloadable
        CSV/PDF export. Only a single content block is supported by this cmdlet; the underlying
        API allows up to 5 per task for callers building the raw body directly.

        Field names for the request body (name, language, retention_number, format, time_segment,
        begin_time/end_time, content[].report_type/compute_mode/object_type) come from the
        OceanStor REST Interface Reference. The content[] object-ID-list and indicator-list field
        names (object_id_list, indicator_list) are this cmdlet's own naming assumption -- they are
        not given literally in the reference excerpt available during implementation and are
        unverified against a live array. See PerformanceGAP.md Phase 4 notes.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Report task name.

    .PARAMETER Language
        Report language code. Defaults to 'en'.

    .PARAMETER RetentionNumber
        Number of historical report runs the array retains for this task, 1-30. Defaults to 1.

    .PARAMETER Format
        Export format: CSV (default), PDF, or CSV-ORIGINAL (original per-sample granularity,
        limited to a 24-hour window).

    .PARAMETER TimeSegment
        Reporting window: OneHour, OneDay, OneWeek, OneMonth, OneYear, or Customer. StartTime and
        EndTime are mandatory when TimeSegment is Customer.

    .PARAMETER StartTime
        Window start (mandatory when TimeSegment is Customer).

    .PARAMETER EndTime
        Window end (mandatory when TimeSegment is Customer).

    .PARAMETER ObjectType
        Object type the report covers (see Get-DMPerformanceReportObjectTypeMap for the
        friendly-name -> API-string mapping).

    .PARAMETER ObjectId
        One or more object IDs to include in the report.

    .PARAMETER Metric
        One or more friendly metric names (see Get-DMPerformanceIndicatorMap). Defaults to
        Get-DMPerformance's own default set when omitted.

    .PARAMETER ComputeMode
        How samples are aggregated within the reporting window: Avg (default) or Max.

    .INPUTS
        None

    .OUTPUTS
        OceanstorPerformanceReportTask

    .EXAMPLE
        PS> New-DMPerformanceReportTask -Name 'lun-history' -ObjectType LUN -ObjectId '1' -TimeSegment OneWeek

    .EXAMPLE
        PS> New-DMPerformanceReportTask -Name 'lun-custom' -ObjectType LUN -ObjectId '1','2' -TimeSegment Customer -StartTime (Get-Date).AddDays(-2) -EndTime (Get-Date)

    .NOTES
        Filename: New-DMPerformanceReportTask.ps1
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([OceanstorPerformanceReportTask])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$Language = 'en',

        [ValidateRange(1, 30)]
        [int]$RetentionNumber = 1,

        [ValidateSet('CSV', 'PDF', 'CSV-ORIGINAL')]
        [string]$Format = 'CSV',

        [Parameter(Mandatory = $true)]
        [ValidateSet('OneHour', 'OneDay', 'OneWeek', 'OneMonth', 'OneYear', 'Customer')]
        [string]$TimeSegment,

        [datetime]$StartTime,

        [datetime]$EndTime,

        [Parameter(Mandatory = $true)]
        [ValidateSet('LUN', 'Controller', 'StoragePool', 'Disk', 'Host', 'System', 'FCPort', 'EthernetPort')]
        [string]$ObjectType,

        [Parameter(Mandatory = $true)]
        [string[]]$ObjectId,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (Get-DMPerformanceIndicatorMap).Keys | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [ValidateScript({
                $validNames = (Get-DMPerformanceIndicatorMap).Keys
                foreach ($metricName in $_) {
                    if ($metricName -notin $validNames) {
                        throw "Unknown performance metric '$metricName'. Valid metrics: $($validNames -join ', ')"
                    }
                }
                return $true
            })]
        [string[]]$Metric,

        [ValidateSet('Avg', 'Max')]
        [string]$ComputeMode = 'Avg'
    )

    begin {
        if ($TimeSegment -eq 'Customer' -and (-not $PSBoundParameters.ContainsKey('StartTime') -or -not $PSBoundParameters.ContainsKey('EndTime'))) {
            throw 'New-DMPerformanceReportTask: StartTime and EndTime are mandatory when TimeSegment is Customer.'
        }
        if ($PSBoundParameters.ContainsKey('StartTime') -and $PSBoundParameters.ContainsKey('EndTime') -and $EndTime -le $StartTime) {
            throw 'New-DMPerformanceReportTask: EndTime must be later than StartTime.'
        }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $timeSegmentMap = Get-DMPerformanceReportTimeSegmentMap
            $objectTypeMap = Get-DMPerformanceReportObjectTypeMap
            $indicatorMap = Get-DMPerformanceIndicatorMap
            $metricNames = @(if ($PSBoundParameters.ContainsKey('Metric') -and $Metric) { $Metric } else { $script:DMDefaultPerformanceMetrics })

            $body = @{
                name             = $Name
                language         = $Language
                retention_number = $RetentionNumber
                format           = $Format
                time_segment     = $timeSegmentMap[$TimeSegment]
                content          = @(
                    @{
                        report_type    = 'performance'
                        compute_mode   = $ComputeMode.ToLowerInvariant()
                        object_type    = $objectTypeMap[$ObjectType]
                        object_id_list = @($ObjectId)
                        indicator_list = @($metricNames | ForEach-Object { $indicatorMap[$_].Id })
                    }
                )
            }

            if ($TimeSegment -eq 'Customer') {
                $body.begin_time = [System.DateTimeOffset]::new($StartTime.ToUniversalTime()).ToUnixTimeSeconds()
                $body.end_time = [System.DateTimeOffset]::new($EndTime.ToUniversalTime()).ToUnixTimeSeconds()
            }

            if (-not $PSCmdlet.ShouldProcess($Name, 'Create performance report task')) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'pms/report_task' -BodyData $body -ApiV2
            $response = $response | Assert-DMApiSuccess
            return [OceanstorPerformanceReportTask]::new($response.data, $session)
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
