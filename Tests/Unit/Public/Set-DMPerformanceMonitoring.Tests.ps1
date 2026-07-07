BeforeDiscovery {
    $script:testModule = New-Module -Name SetDMPerformanceMonitoringTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMPerformanceMonitoring.ps1"

        Export-ModuleMember -Function Set-DMPerformanceMonitoring
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name SetDMPerformanceMonitoringTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SetDMPerformanceMonitoringTestModule {
    Describe 'Set-DMPerformanceMonitoring' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ error = [pscustomobject]@{ code = 0; description = '' } }
            }
        }

        It 'rejects an invalid SamplingIntervalSeconds value' {
            { Set-DMPerformanceMonitoring -WebSession $script:session -SamplingIntervalSeconds 15 -Confirm:$false } | Should -Throw
        }

        It 'rejects an invalid ArchiveIntervalSeconds value' {
            { Set-DMPerformanceMonitoring -WebSession $script:session -ArchiveIntervalSeconds 999 -Confirm:$false } | Should -Throw
        }

        It 'only includes explicitly bound parameters in the PUT body (partial update)' {
            Set-DMPerformanceMonitoring -WebSession $script:session -SamplingIntervalSeconds 30 -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PUT' -and
                $Resource -eq 'performance_statistic_strategy' -and
                $BodyData.Count -eq 1 -and
                $BodyData.CMO_STATISTIC_INTERVAL -eq 30
            }
        }

        It 'includes every bound parameter when multiple are supplied' {
            Set-DMPerformanceMonitoring -WebSession $script:session -SamplingIntervalSeconds 60 -ArchiveIntervalSeconds 600 -EnableArchive $true -AutoStop $false -MaxDays 30 -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.CMO_STATISTIC_INTERVAL -eq 60 -and
                $BodyData.CMO_STATISTIC_ARCHIVE_TIME -eq 600 -and
                $BodyData.CMO_STATISTIC_ARCHIVE_SWITCH -eq 1 -and
                $BodyData.CMO_STATISTIC_AUTO_STOP -eq 0 -and
                $BodyData.CMO_STATISTIC_MAX_TIME -eq 30
            }
        }

        It 'warns and does not call Invoke-DeviceManager when no parameters are specified' {
            Mock Write-Warning {}

            Set-DMPerformanceMonitoring -WebSession $script:session -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
            Should -Invoke Write-Warning -Times 1 -Exactly
        }

        It 'does not call Invoke-DeviceManager under -WhatIf' {
            Set-DMPerformanceMonitoring -WebSession $script:session -SamplingIntervalSeconds 30 -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }
    }
}
