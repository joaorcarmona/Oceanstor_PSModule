BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMPerformanceMonitoringTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceMonitoring.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformanceMonitoring.ps1"

        Export-ModuleMember -Function Get-DMPerformanceMonitoring, New-DMPerformanceMonitoringStatus
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMPerformanceMonitoringTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMPerformanceMonitoringTestModule {
    Describe 'Get-DMPerformanceMonitoring' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'GETs both the switch and strategy resources' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            CMO_PERFORMANCE_SWITCH    = '1'
                            CMO_PERFORMANCE_BEGIN_TIME = '1700000000'
                        }
                    )
                }
            } -ParameterFilter { $Resource -eq 'performance_statistic_switch' }

            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            CMO_STATISTIC_INTERVAL       = '30'
                            CMO_STATISTIC_ARCHIVE_SWITCH = '1'
                            CMO_STATISTIC_ARCHIVE_TIME   = '300'
                            CMO_STATISTIC_AUTO_STOP      = '0'
                            CMO_STATISTIC_MAX_TIME       = '90'
                        }
                    )
                }
            } -ParameterFilter { $Resource -eq 'performance_statistic_strategy' }

            $null = Get-DMPerformanceMonitoring -WebSession $script:session

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Method -eq 'GET' -and $Resource -eq 'performance_statistic_switch' }
            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Method -eq 'GET' -and $Resource -eq 'performance_statistic_strategy' }
        }

        It 'merges both responses into a single OceanStor.PerformanceMonitoringStatus object' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            CMO_PERFORMANCE_SWITCH    = '1'
                            CMO_PERFORMANCE_BEGIN_TIME = '1700000000'
                        }
                    )
                }
            } -ParameterFilter { $Resource -eq 'performance_statistic_switch' }

            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{
                            CMO_STATISTIC_INTERVAL       = '30'
                            CMO_STATISTIC_ARCHIVE_SWITCH = '1'
                            CMO_STATISTIC_ARCHIVE_TIME   = '300'
                            CMO_STATISTIC_AUTO_STOP      = '0'
                            CMO_STATISTIC_MAX_TIME       = '90'
                        }
                    )
                }
            } -ParameterFilter { $Resource -eq 'performance_statistic_strategy' }

            $result = Get-DMPerformanceMonitoring -WebSession $script:session

            $result.PSTypeNames | Should -Contain 'OceanStor.PerformanceMonitoringStatus'
            $result.Enabled | Should -BeTrue
            $result.BeginTime | Should -Be '1700000000'
            $result.SamplingIntervalSeconds | Should -Be 30
            $result.ArchiveEnabled | Should -BeTrue
            $result.ArchiveIntervalSeconds | Should -Be 300
            $result.AutoStop | Should -BeFalse
            $result.MaxDays | Should -Be 90
        }
    }
}
