BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMPerformanceHistoryTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function New-DMPerformanceReportTask { param($WebSession, $Name, $TimeSegment, $StartTime, $EndTime, $Format, $RetentionNumber, $ObjectType, $ObjectId, $Metric, $ComputeMode, [switch]$Confirm) }
        function Invoke-DMPerformanceReportTask { param($WebSession, $Id, $TimeoutSec, [switch]$Confirm) }
        function Save-DMPerformanceReportFile { param($WebSession, $LogId, $Path, [switch]$Force) }
        function Import-DMPerformanceReportCsv { param($ZipPath) }
        function Remove-DMPerformanceReportTask { param($WebSession, $Id, [switch]$Confirm) }
        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, [switch]$ApiV2) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceSample.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformance.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformanceHistory.ps1"

        Export-ModuleMember -Function Get-DMPerformanceHistory, New-DMPerformanceReportTask, Invoke-DMPerformanceReportTask, `
            Save-DMPerformanceReportFile, Import-DMPerformanceReportCsv, Invoke-DeviceManager, `
            Get-DMPerformanceIndicatorMap, New-DMPerformanceSample
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMPerformanceHistoryTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMPerformanceHistoryTestModule {
    Describe 'Get-DMPerformanceHistory' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
            $script:callOrder = [System.Collections.Generic.List[string]]::new()

            Mock New-DMPerformanceReportTask {
                $script:callOrder.Add('New-DMPerformanceReportTask')
                [pscustomobject]@{ Id = 'task-01'; Name = $Name }
            }
            Mock Invoke-DMPerformanceReportTask {
                $script:callOrder.Add('Invoke-DMPerformanceReportTask')
                [pscustomobject]@{ LogId = 'log-01'; TaskId = $Id; Status = 'finished' }
            }
            Mock Save-DMPerformanceReportFile {
                $script:callOrder.Add('Save-DMPerformanceReportFile')
            }
            Mock Import-DMPerformanceReportCsv {
                $script:callOrder.Add('Import-DMPerformanceReportCsv')
                @(
                    [pscustomobject]@{ object_id = '1'; timestamp = '1700000000'; TotalIOPS = '100'; AvgLatencyMs = '5.5'; SourceFile = 'lun.csv' }
                )
            }
            Mock Remove-DMPerformanceReportTask {
                $script:callOrder.Add('Remove-DMPerformanceReportTask')
            }
            Mock Invoke-DeviceManager {
                $script:callOrder.Add('Invoke-DeviceManager')
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
            }
        }

        It 'runs the full create -> run -> download -> parse -> cleanup pipeline in order' {
            $start = (Get-Date).AddDays(-1)
            $end = Get-Date

            $result = Get-DMPerformanceHistory -WebSession $script:session -ObjectType LUN -ObjectId '1' -Metric TotalIOPS, AvgLatencyMs -StartTime $start -EndTime $end

            $script:callOrder | Should -Be @(
                'New-DMPerformanceReportTask',
                'Invoke-DMPerformanceReportTask',
                'Save-DMPerformanceReportFile',
                'Import-DMPerformanceReportCsv',
                'Invoke-DeviceManager',
                'Remove-DMPerformanceReportTask'
            )

            $result.Count | Should -Be 1
            $result[0].TotalIOPS | Should -Be 100
            $result[0].AvgLatencyMs | Should -Be 5.5
            $result[0].ObjectId | Should -Be '1'
            $result[0].Timestamp | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1700000000).UtcDateTime)
        }

        It 'maps the last N CSV columns positionally to the requested metrics in order' {
            Get-DMPerformanceHistory -WebSession $script:session -ObjectType LUN -ObjectId '1' -Metric TotalIOPS, AvgLatencyMs -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) | Out-Null

            Should -Invoke New-DMPerformanceReportTask -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'TotalIOPS,AvgLatencyMs'
            }
        }

        It 'defaults to the module default metric set when -Metric is omitted' {
            Get-DMPerformanceHistory -WebSession $script:session -ObjectType LUN -ObjectId '1' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) | Out-Null

            Should -Invoke New-DMPerformanceReportTask -Times 1 -Exactly -ParameterFilter {
                (@($Metric)).Count -eq $script:DMDefaultPerformanceMetrics.Count
            }
        }

        It 'defaults to the NAS metric set for FileSystem when -Metric is omitted' {
            Get-DMPerformanceHistory -WebSession $script:session -ObjectType FileSystem -ObjectId '1' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) | Out-Null

            Should -Invoke New-DMPerformanceReportTask -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'FileSystem' -and
                (@($Metric)).Count -eq $script:DMDefaultNasPerformanceMetrics.Count -and
                (@($Metric) -contains 'Ops') -and
                (@($Metric) -contains 'AvgReadOpsResponseTimeUs')
            }
        }

        It 'accumulates piped ObjectId values before creating a single report task' {
            '1', '2', '3' | Get-DMPerformanceHistory -WebSession $script:session -ObjectType LUN -Metric TotalIOPS -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) | Out-Null

            Should -Invoke New-DMPerformanceReportTask -Times 1 -Exactly -ParameterFilter {
                (@($ObjectId) -join ',') -eq '1,2,3'
            }
        }

        It 'returns an empty ArrayList and makes no calls when no ObjectId is supplied' {
            $result = @() | Get-DMPerformanceHistory -WebSession $script:session -ObjectType LUN -Metric TotalIOPS -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)

            @($result).Count | Should -Be 0
            Should -Invoke New-DMPerformanceReportTask -Times 0 -Exactly
        }

        It 'skips cleanup when -KeepReportTask is specified' {
            Get-DMPerformanceHistory -WebSession $script:session -ObjectType LUN -ObjectId '1' -Metric TotalIOPS -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -KeepReportTask | Out-Null

            Should -Invoke Remove-DMPerformanceReportTask -Times 0 -Exactly
            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'still cleans up the report task even when parsing throws' {
            Mock Import-DMPerformanceReportCsv { throw 'boom' }

            { Get-DMPerformanceHistory -WebSession $script:session -ObjectType LUN -ObjectId '1' -Metric TotalIOPS -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -ErrorAction Stop } | Should -Throw '*boom*'

            Should -Invoke Remove-DMPerformanceReportTask -Times 1 -Exactly
        }

        It 'rejects an unknown metric name at parameter binding' {
            { Get-DMPerformanceHistory -WebSession $script:session -ObjectType LUN -ObjectId '1' -Metric 'NotARealMetric' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) } | Should -Throw '*Unknown performance metric*'
        }
    }
}
