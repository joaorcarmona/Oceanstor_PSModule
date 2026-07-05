$script:DMPerformanceObjectTypeMap = [ordered]@{
    Disk         = 10
    LUN          = 11
    EthernetPort = 213
    BondPort     = 235
    FCPort       = 212
    StoragePool  = 216
    Controller   = 207
    Host         = 21
    System       = 201
}

$script:DMDefaultPerformanceMetrics = @(
    'TotalIOPS', 'ReadIOPS', 'WriteIOPS',
    'BandwidthMBps', 'ReadBandwidthMBps', 'WriteBandwidthMBps',
    'AvgLatencyMs', 'ReadLatencyMs', 'WriteLatencyMs',
    'QueueLength'
)

function Get-DMPerformance {
    <#
    .SYNOPSIS
        Retrieves realtime performance samples for OceanStor objects.

    .DESCRIPTION
        Wraps the performance_data batch interface (POST, per doc section 4.14.1.1.2). Returns one
        OceanStor.PerformanceSample per requested object, with one property per requested metric.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER ObjectType
        The type of object to retrieve performance data for.

    .PARAMETER ObjectId
        One or more object IDs to retrieve performance data for. Pipeline-able.

    .PARAMETER Metric
        One or more friendly metric names (see Get-DMPerformanceIndicatorMap). Defaults to a
        common IOPS/bandwidth/latency/queue-length set when omitted.

    .INPUTS
        System.String

    .OUTPUTS
        System.Collections.ArrayList

    .EXAMPLE
        PS> Get-DMPerformance -ObjectType Controller -ObjectId '0A','0B'

    .EXAMPLE
        PS> Get-DMPerformance -ObjectType LUN -ObjectId '1' -Metric TotalIOPS,AvgLatencyMs

    .NOTES
        Filename: Get-DMPerformance.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('LUN', 'Controller', 'StoragePool', 'Disk', 'EthernetPort', 'BondPort', 'FCPort', 'Host', 'System')]
        [string]$ObjectType,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ObjectId,

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
        [string[]]$Metric
    )

    begin {
        $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
        $indicatorMap = Get-DMPerformanceIndicatorMap
        $metricNames = @(if ($PSBoundParameters.ContainsKey('Metric') -and $Metric) { $Metric } else { $script:DMDefaultPerformanceMetrics })
        $indicatorIds = @($metricNames | ForEach-Object { $indicatorMap[$_].Id })
        $objectTypeId = $script:DMPerformanceObjectTypeMap[$ObjectType]
        $collectedIds = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($id in $ObjectId) {
            $collectedIds.Add($id)
        }
    }

    end {
        if ($collectedIds.Count -eq 0) {
            return [System.Collections.ArrayList]::new()
        }

        $body = @{
            object_type = $objectTypeId
            object_list = @($collectedIds)
            indicators  = $indicatorIds
        }

        $maxAttempts = 2
        $attempt = 0
        $data = $null
        while ($attempt -lt $maxAttempts) {
            $attempt++
            try {
                $data = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'performance_data' -BodyData $body | Select-DMResponseData
                break
            }
            catch {
                $isConcurrencyError = "$($_.Exception.Message)" -match '(?i)(being invoked|already in use|concurrent|in progress)'
                if ($isConcurrencyError -and $attempt -lt $maxAttempts) {
                    Start-Sleep -Milliseconds 500
                    continue
                }
                throw
            }
        }

        $samples = [System.Collections.ArrayList]::new()

        foreach ($entry in @($data)) {
            if ($null -eq $entry) { continue }

            $responseIds = @($entry.indicators)
            $responseValues = @($entry.indicator_values)

            $metrics = [ordered]@{}
            for ($i = 0; $i -lt $metricNames.Count; $i++) {
                $name = $metricNames[$i]
                $meta = $indicatorMap[$name]
                $pos = -1
                for ($j = 0; $j -lt $responseIds.Count; $j++) {
                    if ("$($responseIds[$j])" -eq "$($meta.Id)") { $pos = $j; break }
                }
                $raw = if ($pos -ge 0) { $responseValues[$pos] } else { $null }

                if ($null -ne $raw) {
                    $rawDouble = [double]$raw
                    if ($rawDouble -eq -1) {
                        $raw = $null
                    }
                    elseif ($meta.ContainsKey('SourceUnit') -and $meta.SourceUnit -eq 'us' -and $meta.Unit -eq 'ms') {
                        $raw = $rawDouble / 1000.0
                    }
                    else {
                        $raw = $rawDouble
                    }
                }

                $metrics[$name] = $raw
            }

            $timestamp = [DateTimeOffset]::FromUnixTimeSeconds([long]$entry.timestamp).UtcDateTime

            $sample = New-DMPerformanceSample -ObjectType $ObjectType -ObjectId $entry.object_id -Timestamp $timestamp `
                -Metrics $metrics -RawIndicators $responseIds -RawValues $responseValues -Session $session

            [void]$samples.Add($sample)
        }

        return $samples
    }
}
