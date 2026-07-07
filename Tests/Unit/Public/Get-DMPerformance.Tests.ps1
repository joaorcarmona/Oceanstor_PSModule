BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceSample.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformance.ps1"

        Export-ModuleMember -Function Get-DMPerformance, Get-DMPerformanceIndicatorMap, New-DMPerformanceSample
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMPerformanceTestModule {
    Describe 'Get-DMPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'POSTs to performance_data with the resolved object_type/object_list/indicators body' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            object_id        = '0A'
                            timestamp        = 1700000000
                            indicators       = @('22', '25', '28', '21', '23', '26', '370', '384', '385', '19')
                            indicator_values = @('100', '40', '60', '500', '200', '300', '1000', '900', '1100', '5')
                        }
                    )
                }
            }

            $null = Get-DMPerformance -WebSession $script:session -ObjectType Controller -ObjectId '0A'

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Resource -eq 'performance_data' -and
                $BodyData.object_type -eq 207 -and
                (@($BodyData.object_list) -contains '0A') -and
                (@($BodyData.indicators) -contains 22)
            }
        }

        It 'uses the default metric set when -Metric is omitted' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            object_id        = '0A'
                            timestamp        = 1700000000
                            indicators       = @('22', '25', '28', '21', '23', '26', '370', '384', '385', '19')
                            indicator_values = @('100', '40', '60', '500', '200', '300', '1000', '900', '1100', '5')
                        }
                    )
                }
            }

            $result = Get-DMPerformance -WebSession $script:session -ObjectType Controller -ObjectId '0A'

            $result[0].TotalIOPS | Should -Be 100
            $result[0].AvgLatencyMs | Should -Be 1
            $result[0].QueueLength | Should -Be 5
        }

        It 'resolves FileSystem to object_type 40 and uses the NAS default metric set when -Metric is omitted' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            object_id        = 'FS1'
                            timestamp        = 1700000000
                            indicators       = @('182', '232', '233', '23', '26', '524', '525')
                            indicator_values = @('100', '40', '60', '500', '200', '2500', '3500')
                        }
                    )
                }
            }

            $result = Get-DMPerformance -WebSession $script:session -ObjectType FileSystem -ObjectId 'FS1'

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.object_type -eq 40 -and
                (@($BodyData.indicators)).Count -eq $script:DMDefaultNasPerformanceMetrics.Count -and
                (@($BodyData.indicators) -contains 182) -and
                (@($BodyData.indicators) -contains 524) -and
                (@($BodyData.indicators) -contains 525)
            }

            $result[0].Ops | Should -Be 100
            $result[0].AvgReadOpsResponseTimeUs | Should -Be 2500
            $result[0].AvgWriteOpsResponseTimeUs | Should -Be 3500
        }

        It 'keeps every NAS default metric resolvable through the indicator map' {
            $map = Get-DMPerformanceIndicatorMap
            foreach ($name in $script:DMDefaultNasPerformanceMetrics) {
                $map.Contains($name) | Should -BeTrue -Because "NAS default metric '$name' must exist in the indicator map"
            }
        }

        It 'resolves friendly metric names to indicator IDs positionally into sample properties' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            object_id        = 'LUN1'
                            timestamp        = 1700000000
                            indicators       = @('25', '28')
                            indicator_values = @('11', '22')
                        }
                    )
                }
            }

            $result = Get-DMPerformance -WebSession $script:session -ObjectType LUN -ObjectId 'LUN1' -Metric ReadIOPS, WriteIOPS

            $result[0].ReadIOPS | Should -Be 11
            $result[0].WriteIOPS | Should -Be 22
        }

        It 'converts a raw -1 sentinel value to $null' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            object_id        = '0A'
                            timestamp        = 1700000000
                            indicators       = @('18')
                            indicator_values = @('-1')
                        }
                    )
                }
            }

            $result = Get-DMPerformance -WebSession $script:session -ObjectType Controller -ObjectId '0A' -Metric UsagePercent

            $result[0].UsagePercent | Should -BeNullOrEmpty
        }

        It 'converts microsecond latency indicators to milliseconds' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            object_id        = '0A'
                            timestamp        = 1700000000
                            indicators       = @('370')
                            indicator_values = @('2500')
                        }
                    )
                }
            }

            $result = Get-DMPerformance -WebSession $script:session -ObjectType Controller -ObjectId '0A' -Metric AvgLatencyMs

            $result[0].AvgLatencyMs | Should -Be 2.5
        }

        It 'converts the epoch-seconds timestamp to a UTC datetime' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            object_id        = '0A'
                            timestamp        = 1700000000
                            indicators       = @('22')
                            indicator_values = @('1')
                        }
                    )
                }
            }

            $result = Get-DMPerformance -WebSession $script:session -ObjectType Controller -ObjectId '0A' -Metric TotalIOPS

            $result[0].Timestamp | Should -BeOfType [datetime]
            $result[0].Timestamp | Should -Be ([datetimeoffset]::FromUnixTimeSeconds(1700000000).UtcDateTime)
        }

        It 'retries once on a concurrent-invocation error and then succeeds' {
            $script:callCount = 0
            Mock Invoke-DeviceManager {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    throw 'The interface is being invoked by another session'
                }
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            object_id        = '0A'
                            timestamp        = 1700000000
                            indicators       = @('22')
                            indicator_values = @('1')
                        }
                    )
                }
            }

            $result = Get-DMPerformance -WebSession $script:session -ObjectType Controller -ObjectId '0A' -Metric TotalIOPS

            $result[0].TotalIOPS | Should -Be 1
            Should -Invoke Invoke-DeviceManager -Times 2 -Exactly
        }

        It 'surfaces the error after a second consecutive concurrent-invocation failure' {
            Mock Invoke-DeviceManager {
                throw 'The interface is being invoked by another session'
            }

            { Get-DMPerformance -WebSession $script:session -ObjectType Controller -ObjectId '0A' -Metric TotalIOPS } | Should -Throw
            Should -Invoke Invoke-DeviceManager -Times 2 -Exactly
        }

        It 'rejects an unknown metric name' {
            { Get-DMPerformance -WebSession $script:session -ObjectType Controller -ObjectId '0A' -Metric 'NotAMetric' } | Should -Throw
        }
    }
}
