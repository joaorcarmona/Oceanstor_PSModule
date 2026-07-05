BeforeDiscovery {
    $script:testModule = New-Module -Name DisableDMPerformanceMonitoringTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Disable-DMPerformanceMonitoring.ps1"

        Export-ModuleMember -Function Disable-DMPerformanceMonitoring
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name DisableDMPerformanceMonitoringTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope DisableDMPerformanceMonitoringTestModule {
    Describe 'Disable-DMPerformanceMonitoring' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ error = [pscustomobject]@{ code = 0; description = '' } }
            }
        }

        It 'PUTs performance_statistic_switch with CMO_PERFORMANCE_SWITCH = 0' {
            Disable-DMPerformanceMonitoring -WebSession $script:session -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PUT' -and
                $Resource -eq 'performance_statistic_switch' -and
                $BodyData.CMO_PERFORMANCE_SWITCH -eq 0
            }
        }

        It 'does not call Invoke-DeviceManager under -WhatIf' {
            Disable-DMPerformanceMonitoring -WebSession $script:session -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }
    }
}
