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

        $this.Begin = if ($Raw.begin_time) { [DateTimeOffset]::FromUnixTimeSeconds([long]$Raw.begin_time).UtcDateTime } else { [datetime]::MinValue }
        $this.End = if ($Raw.end_time) { [DateTimeOffset]::FromUnixTimeSeconds([long]$Raw.end_time).UtcDateTime } else { [datetime]::MinValue }

        $this.Contents = @($Raw.content | ForEach-Object {
                [pscustomobject]@{
                    ReportType    = $_.report_type
                    ComputeMode   = $_.compute_mode
                    ObjectType    = $_.object_type
                    ObjectIdList  = @($_.object_id_list)
                    IndicatorList = @($_.indicator_list)
                }
            })
    }

    [psobject] Delete() {
        return Remove-DMPerformanceReportTask -WebSession $this.Session -Id $this.Id -Confirm:$false
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

    $log = [pscustomobject]@{
        PSTypeName = 'OceanStor.PerformanceReportLog'
        LogId      = $Raw.id
        TaskId     = $Raw.task_id
        Status     = $Raw.status
        Raw        = $Raw
        Session    = $Session
    }

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]@('LogId', 'TaskId', 'Status'))
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $log | Add-Member MemberSet PSStandardMembers $standardMembers -Force

    return $log
}
