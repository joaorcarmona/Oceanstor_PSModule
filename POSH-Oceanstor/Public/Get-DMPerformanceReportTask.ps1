function Get-DMPerformanceReportTask {
    <#
    .SYNOPSIS
        Gets Huawei Oceanstor performance report tasks.

    .DESCRIPTION
        Gets performance report tasks via the pms/report_task resource (v2 API). Filtering is
        done client-side after fetching the full task list, since pms/report_task's support for
        server-side filter= queries has not been confirmed against a live array.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Optional task name to search for, positional. When omitted, every task is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .PARAMETER Id
        Optional task ID to search for. Mutually exclusive with Name (enforced by parameter set). Returns exactly one task, exact match only, no wildcard support.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanstorPerformanceReportTask

    .EXAMPLE
        PS> Get-DMPerformanceReportTask

    .EXAMPLE
        PS> Get-DMPerformanceReportTask -Name 'lun-history'

    .EXAMPLE
        PS> Get-DMPerformanceReportTask -Id '1'

    .NOTES
        Filename: Get-DMPerformanceReportTask.ps1
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    # String form: class type literals in attributes do not resolve inside module scope.
    [OutputType('OceanstorPerformanceReportTask')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $false)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'pms/report_task' -ApiV2
    $tasks = New-Object System.Collections.ArrayList

    foreach ($task in $response) {
        [void]$tasks.Add([OceanstorPerformanceReportTask]::new($task, $session))
    }

    $result = switch ($PSCmdlet.ParameterSetName) {
        'ById' {
            $tasks | Where-Object { $_.Id -eq $Id }
        }
        default {
            if ($Name) {
                $tasks | Where-Object { $_.Name -like $Name }
            }
            else {
                $tasks
            }
        }
    }

    return @($result)
}
