class OceanstorPerformanceReportTask {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}

    [string]$Id
    [string]$Name
    [string]$Language
    [string]${Retention Number}
    [string]$Format
    [string]${Time Segment}
    [datetime]$Begin
    [datetime]$End
    [object[]]$Contents

    OceanstorPerformanceReportTask([pscustomobject]$Raw, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Id = $Raw.id
        $this.Name = $Raw.name
        $this.Language = $Raw.language
        $this.{Retention Number} = $Raw.retention_number
        $this.Format = $Raw.format
        $this.{Time Segment} = $Raw.time_segment

        # Live arrays report begin_time/end_time in epoch milliseconds (13 digits),
        # while the documented seconds form must remain accepted for compatibility.
        $this.Begin = [OceanstorPerformanceReportTask]::ConvertFromEpoch($Raw.begin_time)
        $this.End = [OceanstorPerformanceReportTask]::ConvertFromEpoch($Raw.end_time)

        $this.Contents = @($Raw.content | ForEach-Object {
                [pscustomobject]@{
                    ReportType    = $_.report_type
                    ComputeMode   = $_.compute_mode
                    ObjectType    = $_.object_type
                    ObjectIdList  = @($_.entities | ForEach-Object { $_.id })
                    IndicatorList = @($_.indicators.basic)
                }
            })
    }

    [psobject] Delete() {
        return Remove-DMPerformanceReportTask -WebSession $this.Session -Id $this.Id -Confirm:$false
    }

    static hidden [datetime] ConvertFromEpoch([object]$Value) {
        if (-not $Value) { return [datetime]::MinValue }
        $epoch = [long]$Value
        # 253402300799 is 9999-12-31 in seconds; anything larger is milliseconds.
        if ($epoch -gt 253402300799) {
            return [DateTimeOffset]::FromUnixTimeMilliseconds($epoch).UtcDateTime
        }
        return [DateTimeOffset]::FromUnixTimeSeconds($epoch).UtcDateTime
    }
}

function New-DMPerformanceReportLog {
    <#
    .SYNOPSIS
        Builds an OceanStor.PerformanceReportLog object from a raw pms/report_task/task_log entry.

    .DESCRIPTION
        task_log entries are represented with a lightweight pscustomobject factory rather than a
        full class, because the exact status field name/values have not been confirmed against a
        live array (see PerformanceGAP.md Phase 4 notes) -- a factory is lower-risk to adjust than
        a class's typed properties once that is verified.

    .PARAMETER Raw
        The raw task_log entry returned by the API.

    .PARAMETER Session
        The session the log entry was retrieved with, so Save-DMPerformanceReportFile can be
        chained via the pipeline.

    .OUTPUTS
        pscustomobject (PSTypeName 'OceanStor.PerformanceReportLog')

    .NOTES
        Filename: class-OceanstorPerformanceReportTask.ps1
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Raw,

        [Parameter(Mandatory = $false)]
        [pscustomobject]$Session
    )

    # Live task_log entries (Dorado V600R005C27) carry log_id/file_name/file_size/
    # generate_time and no status field -- an entry only appears once its export
    # file is ready. id/status are kept as fallbacks for differing firmware.
    $log = [pscustomobject]@{
        PSTypeName = 'OceanStor.PerformanceReportLog'
        LogId      = if ($Raw.log_id) { $Raw.log_id } else { $Raw.id }
        TaskId     = $Raw.task_id
        Status     = $Raw.status
        FileName   = $Raw.file_name
        FileSize   = $Raw.file_size
        Raw        = $Raw
        Session    = $Session
    }

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]@('LogId', 'TaskId', 'Status'))
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $log | Add-Member MemberSet PSStandardMembers $standardMembers -Force

    return $log
}
