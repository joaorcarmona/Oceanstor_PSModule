function Save-DMPerformanceReportFile {
    <#
    .SYNOPSIS
        Downloads a Huawei Oceanstor performance report export file.

    .DESCRIPTION
        Downloads the report zip produced by a report task run (see Invoke-DMPerformanceReportTask)
        via the pms/report_task/file resource (GET, v2 API, binary). Wraps Save-DMDeviceManagerFile.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER LogId
        ID of the export log entry to download. Accepts the object returned by
        Invoke-DMPerformanceReportTask via pipeline property name (LogId).

    .PARAMETER TaskId
        ID of the report task the log belongs to. Both task_id and log_id are mandatory
        on the live pms/report_task/file interface (omitting task_id returns error 65540).
        Accepts the object returned by Invoke-DMPerformanceReportTask via pipeline
        property name (TaskId).

    .PARAMETER Path
        Local file path to save the download to.

    .PARAMETER Force
        Overwrite Path if it already exists.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.IO.FileInfo

    .EXAMPLE
        PS> Save-DMPerformanceReportFile -LogId '10' -TaskId '1' -Path 'C:\temp\report.zip'

    .EXAMPLE
        PS> Invoke-DMPerformanceReportTask -Name 'lun-history' | Save-DMPerformanceReportFile -Path 'C:\temp\report.zip'

    .NOTES
        Filename: Save-DMPerformanceReportFile.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogId,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskId,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$Force
    )

    process {
        try {
            if ((Test-Path -LiteralPath $Path) -and -not $Force) {
                throw "Save-DMPerformanceReportFile: '$Path' already exists. Use -Force to overwrite."
            }

            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            return Save-DMDeviceManagerFile -WebSession $session -Resource "pms/report_task/file?log_id=$LogId&task_id=$TaskId" -OutFile $Path -ApiV2
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
