BeforeDiscovery {
    $script:testModule = New-Module -Name EnableDMPerformanceMonitoringTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Enable-DMPerformanceMonitoring.ps1"

        Export-ModuleMember -Function Enable-DMPerformanceMonitoring
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name EnableDMPerformanceMonitoringTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope EnableDMPerformanceMonitoringTestModule {
    Describe 'Enable-DMPerformanceMonitoring' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ error = [pscustomobject]@{ code = 0; description = '' } }
            }
        }

        It 'PUTs performance_statistic_switch with CMO_PERFORMANCE_SWITCH = 1' {
            Enable-DMPerformanceMonitoring -WebSession $script:session -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PUT' -and
                $Resource -eq 'performance_statistic_switch' -and
                $BodyData.CMO_PERFORMANCE_SWITCH -eq 1
            }
        }

        It 'does not call Invoke-DeviceManager under -WhatIf' {
            Enable-DMPerformanceMonitoring -WebSession $script:session -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }
    }
}
