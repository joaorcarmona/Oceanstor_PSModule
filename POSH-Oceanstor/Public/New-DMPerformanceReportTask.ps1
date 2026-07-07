function New-DMPerformanceReportTask {
    <#
    .SYNOPSIS
        Creates an OceanStor performance report task for historical/ranged performance data.

    .DESCRIPTION
        Wraps the pms/report_task create interface (POST, v2 API). A report task defines what to
        collect -- a single object type/entity list, report_type 'performance' or 'capacity'
        (-ReportType) -- and over what time window. Running it (Invoke-DMPerformanceReportTask)
        generates a downloadable CSV/PDF export. Only a single content block is supported by this
        cmdlet; the underlying API allows up to 5 per task for callers building the raw body
        directly.

        The request body follows the documented create-report-task schema: top-level name,
        language, retention_number, format, time_segment, begin_time/end_time and the
        mandatory export schedule (frequency 'day', run_time 00:00); per-content report_type,
        object_type (documented name string), object_type_enum (numeric ID), sort_entities
        ('customer'), indicators (basic/advance ID arrays) and
        entities (id/name plus a JSON-encoded data string). Performance contents additionally
        carry compute_mode, sort_indicator, sort_type ('top') and limit; capacity contents send
        an empty indicator set and omit those performance-only fields. The documented limit field
        only accepts 5, 10 or 16, so the smallest value covering the entity count is chosen.

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
        friendly-name -> name/enum mapping).

    .PARAMETER ObjectId
        One or more object IDs to include in the report. The documented entity limit values are
        5/10/16; more than 16 IDs requires -Force.

    .PARAMETER ReportType
        Report content type: Performance (default) or Capacity. Capacity reports send an empty
        indicator set and omit the performance-only compute/sort/limit fields.

    .PARAMETER Metric
        One or more friendly metric names (see Get-DMPerformanceIndicatorMap). Defaults to
        Get-DMPerformance's own default set when omitted. Ignored for -ReportType Capacity.

    .PARAMETER ComputeMode
        How samples are aggregated within the reporting window: Avg (default) or Max. Only sent
        for -ReportType Performance.

    .PARAMETER Force
        Submit even when more than 16 object IDs are supplied (beyond the largest documented
        limit value).

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
    # String form: class type literals in attributes do not resolve inside module scope.
    [OutputType('OceanstorPerformanceReportTask')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        # The doc says names may be 32 characters, but the live array acknowledges
        # 32-character names with success and never creates the task; 31 is the
        # real limit (observed on Dorado V600R005C27), so reject longer up front.
        [ValidateLength(1, 31)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
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
        [ValidateSet('LUN', 'FileSystem', 'Controller', 'StoragePool', 'Disk', 'Host', 'System', 'FCPort', 'EthernetPort')]
        [string]$ObjectType,

        [Parameter(Mandatory = $true)]
        [string[]]$ObjectId,

        [ValidateSet('Performance', 'Capacity')]
        [string]$ReportType = 'Performance',

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
        [string]$ComputeMode = 'Avg',

        [switch]$Force
    )

    begin {
        if ($TimeSegment -eq 'Customer' -and (-not $PSBoundParameters.ContainsKey('StartTime') -or -not $PSBoundParameters.ContainsKey('EndTime'))) {
            throw 'New-DMPerformanceReportTask: StartTime and EndTime are mandatory when TimeSegment is Customer.'
        }
        if ($PSBoundParameters.ContainsKey('StartTime') -and $PSBoundParameters.ContainsKey('EndTime') -and $EndTime -le $StartTime) {
            throw 'New-DMPerformanceReportTask: EndTime must be later than StartTime.'
        }
        if (@($ObjectId).Count -gt 16) {
            if (-not $Force) {
                throw "New-DMPerformanceReportTask: the report_task interface documents at most 16 entities per content block (limit values 5/10/16); $(@($ObjectId).Count) object IDs were supplied. Use -Force to submit anyway."
            }
            Write-Warning "New-DMPerformanceReportTask: $(@($ObjectId).Count) object IDs exceed the documented maximum of 16 entities; submitting with limit 16."
        }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $timeSegmentMap = Get-DMPerformanceReportTimeSegmentMap
            $objectTypeInfo = (Get-DMPerformanceReportObjectTypeMap)[$ObjectType]

            $entityIds = @($ObjectId)
            $limit = if ($entityIds.Count -le 5) { 5 } elseif ($entityIds.Count -le 10) { 10 } else { 16 }

            $content = @{
                report_type      = $ReportType.ToLowerInvariant()
                object_type      = $objectTypeInfo.Name
                object_type_enum = $objectTypeInfo.Enum
                # Explicit entity lists require the user-defined selection mode.
                sort_entities    = 'customer'
                indicators       = @{
                    basic   = @()
                    advance = @()
                }
                entities    = @($entityIds | ForEach-Object {
                        @{
                            id   = "$_"
                            name = "$_"
                            data = ([ordered]@{ ID = "$_"; NAME = "$_" } | ConvertTo-Json -Compress)
                        }
                    })
            }

            if ($ReportType -eq 'Performance') {
                $indicatorMap = Get-DMPerformanceIndicatorMap
                $metricNames = @(
                    if ($PSBoundParameters.ContainsKey('Metric') -and $Metric) { $Metric }
                    elseif ($ObjectType -eq 'FileSystem') { $script:DMDefaultNasPerformanceMetrics }
                    else { $script:DMDefaultPerformanceMetrics }
                )
                $indicatorIds = @($metricNames | ForEach-Object { $indicatorMap[$_].Id })

                $content.compute_mode = $ComputeMode.ToLowerInvariant()
                $content.indicators.basic = $indicatorIds
                $content.sort_indicator = $indicatorIds[0]
                $content.sort_type = 'top'
                $content.limit = $limit
            }
            elseif ($PSBoundParameters.ContainsKey('Metric') -and $Metric) {
                Write-Warning 'New-DMPerformanceReportTask: -Metric is ignored for -ReportType Capacity; capacity reports take no performance indicators.'
            }

            $body = @{
                name             = $Name
                language         = $Language
                retention_number = $RetentionNumber
                format           = $Format
                time_segment     = $timeSegmentMap[$TimeSegment]
                content          = @($content)
                # The documented schema marks the export schedule as mandatory even for
                # tasks that are only ever run on demand; the array rejects the create
                # request with 1073952264 when frequency/run_time are omitted.
                frequency        = 'day'
                run_time         = @{ hour = 0; min = 0 }
            }

            if ($TimeSegment -eq 'Customer') {
                # The array expresses begin_time/end_time in epoch milliseconds (observed
                # live: query-back returns 13-digit values), not the seconds the doc implies.
                $body.begin_time = [System.DateTimeOffset]::new($StartTime.ToUniversalTime()).ToUnixTimeMilliseconds()
                $body.end_time = [System.DateTimeOffset]::new($EndTime.ToUniversalTime()).ToUnixTimeMilliseconds()
            }

            if (-not $PSCmdlet.ShouldProcess($Name, 'Create performance report task')) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'pms/report_task' -BodyData $body -ApiV2
            $response = $response | Assert-DMApiSuccess
            if ($null -ne $response.data) {
                return [OceanstorPerformanceReportTask]::new($response.data, $session)
            }

            # The array acknowledges creation with data:null (observed live on Dorado
            # V600R005C27), so query the task back by its unique name to return an
            # object that carries the generated task ID.
            $queryResponse = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'pms/report_task' -ApiV2 | Assert-DMApiSuccess
            $createdTask = @($queryResponse.data) | Where-Object { $_.name -eq $Name }
            if (@($createdTask).Count -ne 1) {
                throw "New-DMPerformanceReportTask: the array reported success but the task '$Name' could not be read back by name."
            }
            return [OceanstorPerformanceReportTask]::new(@($createdTask)[0], $session)
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
