function Get-DMFileSystemPerformance {
    <#
    .SYNOPSIS
        Retrieves realtime performance samples for OceanStor file systems.

    .DESCRIPTION
        Thin wrapper around Get-DMPerformance for object type FileSystem. Accepts one or more
        file system objects via pipeline (e.g. from Get-DMFileSystem), batches all piped IDs into
        a single performance_data call per sample -- required because the endpoint cannot be
        invoked concurrently.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER InputObject
        One or more file system objects (OceanstorFileSystem), pipeline-able.

    .PARAMETER Metric
        One or more friendly metric names (see Get-DMPerformanceIndicatorMap). Defaults to
        Get-DMPerformance's own NAS default set when omitted.

    .PARAMETER SampleCount
        Number of samples to take. Defaults to 1.

    .PARAMETER IntervalSeconds
        Delay between samples when SampleCount is greater than 1. Defaults to 5.

    .INPUTS
        OceanstorFileSystem

    .OUTPUTS
        System.Collections.ArrayList

    .EXAMPLE
        PS> Get-DMFileSystem | Get-DMFileSystemPerformance

    .NOTES
        Filename: Get-DMFileSystemPerformance.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object[]]$InputObject,

        [Parameter(Mandatory = $false)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (Get-DMPerformanceIndicatorMap).Keys | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [ValidateScript({
                $validNames = (Get-DMPerformanceIndicatorMap).Keys
                foreach ($name in $_) {
                    if ($name -notin $validNames) {
                        throw "Unknown performance metric '$name'. Valid metrics: $($validNames -join ', ')"
                    }
                }
                return $true
            })]
        [string[]]$Metric,

        [Parameter(Mandatory = $false)]
        [int]$SampleCount = 1,

        [Parameter(Mandatory = $false)]
        [int]$IntervalSeconds = 5
    )

    begin {
        $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
        $ids = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($obj in $InputObject) {
            if ($obj -isnot [OceanstorFileSystem]) {
                throw "Get-DMFileSystemPerformance: InputObject must be an OceanstorFileSystem object."
            }
            $ids.Add($obj.Id)
        }
    }

    end {
        if ($ids.Count -eq 0) { return }

        $params = @{ WebSession = $session; ObjectType = 'FileSystem'; ObjectId = @($ids) }
        if ($PSBoundParameters.ContainsKey('Metric')) { $params.Metric = $Metric }

        for ($s = 0; $s -lt $SampleCount; $s++) {
            Get-DMPerformance @params
            if ($s -lt ($SampleCount - 1)) { Start-Sleep -Seconds $IntervalSeconds }
        }
    }
}
