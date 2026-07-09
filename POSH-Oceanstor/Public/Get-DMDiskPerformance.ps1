function Get-DMDiskPerformance {
    <#
    .SYNOPSIS
        Retrieves realtime performance samples for OceanStor disks.

    .DESCRIPTION
        Thin wrapper around Get-DMPerformance for object type Disk. Accepts one or more
        OceanStorDisks objects via pipeline (e.g. from Get-DMdisk), batches all piped IDs into a
        single performance_data call per sample -- required because the endpoint cannot be
        invoked concurrently.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER InputObject
        One or more OceanStorDisks objects, pipeline-able.

    .PARAMETER Metric
        One or more friendly metric names (see Get-DMPerformanceIndicatorMap). Defaults to
        Get-DMPerformance's own default set when omitted.

    .PARAMETER SampleCount
        Number of samples to take. Defaults to 1.

    .PARAMETER IntervalSeconds
        Delay between samples when SampleCount is greater than 1. Defaults to 5.

    .INPUTS
        OceanStorDisks

    .OUTPUTS
        System.Collections.ArrayList

    .EXAMPLE
        PS> Get-DMdisk | Get-DMDiskPerformance

    .NOTES
        Filename: Get-DMDiskPerformance.ps1
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
                foreach ($metricName in $_) {
                    if ($metricName -notin $validNames) {
                        throw "Unknown performance metric '$metricName'. Valid metrics: $($validNames -join ', ')"
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
            if ($obj -isnot [OceanStorDisks]) {
                throw "Get-DMDiskPerformance: InputObject must be an OceanStorDisks object."
            }
            $ids.Add($obj.Id)
        }
    }

    end {
        if ($ids.Count -eq 0) { return }

        $params = @{ WebSession = $session; ObjectType = 'Disk'; ObjectId = @($ids) }
        if ($PSBoundParameters.ContainsKey('Metric')) { $params.Metric = $Metric }

        for ($s = 0; $s -lt $SampleCount; $s++) {
            Get-DMPerformance @params
            if ($s -lt ($SampleCount - 1)) { Start-Sleep -Seconds $IntervalSeconds }
        }
    }
}
