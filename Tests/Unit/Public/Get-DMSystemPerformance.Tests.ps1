BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMSystemPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPerformance { param($WebSession, $ObjectType, $ObjectId, $Metric) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMSystemPerformance.ps1"

        Export-ModuleMember -Function Get-DMSystemPerformance, Get-DMPerformance, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMSystemPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMSystemPerformanceTestModule {
    Describe 'Get-DMSystemPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'always calls Get-DMPerformance with ObjectType System and ObjectId 0' {
            Mock Get-DMPerformance { }

            Get-DMSystemPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'System' -and $ObjectId -eq '0'
            }
        }

        It 'exposes no InputObject/pipeline parameter' {
            (Get-Command Get-DMSystemPerformance).Parameters.Keys | Should -Not -Contain 'InputObject'
        }

        It 'passes -Metric through when supplied' {
            Mock Get-DMPerformance { }

            Get-DMSystemPerformance -WebSession $script:session -Metric TotalIOPS

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'TotalIOPS'
            }
        }

        It 'omits -Metric when not supplied' {
            Mock Get-DMPerformance { }

            Get-DMSystemPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $null -eq $Metric
            }
        }

        It 'calls Get-DMPerformance SampleCount times' {
            Mock Get-DMPerformance { }
            Mock Start-Sleep { }

            Get-DMSystemPerformance -WebSession $script:session -SampleCount 3 -IntervalSeconds 0

            Should -Invoke Get-DMPerformance -Times 3 -Exactly
        }

        It 'rejects unknown metric name' {
            { Get-DMSystemPerformance -WebSession $script:session -Metric 'NotAMetric' } | Should -Throw
        }
    }
}
