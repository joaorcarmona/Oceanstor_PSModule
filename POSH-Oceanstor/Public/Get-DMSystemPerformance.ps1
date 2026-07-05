function Get-DMSystemPerformance {
    <#
    .SYNOPSIS
        Retrieves realtime performance samples for the OceanStor system (array-level).

    .DESCRIPTION
        Thin wrapper around Get-DMPerformance for object type System. The system object has no
        per-instance ID -- like Get-DMSystem, this cmdlet is a parameterless singleton -- and
        always targets the fixed object ID "0" (confirmed by the REST reference doc's own
        report-task example for object_type_enum 201).

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Metric
        One or more friendly metric names (see Get-DMPerformanceIndicatorMap). Defaults to
        Get-DMPerformance's own default set when omitted.

    .PARAMETER SampleCount
        Number of samples to take. Defaults to 1.

    .PARAMETER IntervalSeconds
        Delay between samples when SampleCount is greater than 1. Defaults to 5.

    .OUTPUTS
        System.Collections.ArrayList

    .EXAMPLE
        PS> Get-DMSystemPerformance

    .NOTES
        Filename: Get-DMSystemPerformance.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

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
    }

    end {
        $params = @{ WebSession = $session; ObjectType = 'System'; ObjectId = '0' }
        if ($PSBoundParameters.ContainsKey('Metric')) { $params.Metric = $Metric }

        for ($s = 0; $s -lt $SampleCount; $s++) {
            Get-DMPerformance @params
            if ($s -lt ($SampleCount - 1)) { Start-Sleep -Seconds $IntervalSeconds }
        }
    }
}
