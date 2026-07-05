BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMHostPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPerformance { param($WebSession, $ObjectType, $ObjectId, $Metric) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMHostPerformance.ps1"

        Export-ModuleMember -Function Get-DMHostPerformance, Get-DMPerformance, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMHostPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMHostPerformanceTestModule {
    Describe 'Get-DMHostPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'batches all piped host IDs into a single Get-DMPerformance call' {
            Mock Get-DMPerformance { }

            $host1 = [OceanStorHost]::new([pscustomobject]@{ ID = 'HOST1' }, $script:session)
            $host2 = [OceanStorHost]::new([pscustomobject]@{ ID = 'HOST2' }, $script:session)

            $host1, $host2 | Get-DMHostPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'Host' -and
                (@($ObjectId) -contains 'HOST1') -and
                (@($ObjectId) -contains 'HOST2')
            }
        }

        It 'passes -Metric through when supplied' {
            Mock Get-DMPerformance { }
            $h = [OceanStorHost]::new([pscustomobject]@{ ID = 'HOST1' }, $script:session)

            $h | Get-DMHostPerformance -WebSession $script:session -Metric TotalIOPS

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'TotalIOPS'
            }
        }

        It 'omits -Metric when not supplied' {
            Mock Get-DMPerformance { }
            $h = [OceanStorHost]::new([pscustomobject]@{ ID = 'HOST1' }, $script:session)

            $h | Get-DMHostPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $null -eq $Metric
            }
        }

        It 'calls Get-DMPerformance SampleCount times' {
            Mock Get-DMPerformance { }
            Mock Start-Sleep { }
            $h = [OceanStorHost]::new([pscustomobject]@{ ID = 'HOST1' }, $script:session)

            $h | Get-DMHostPerformance -WebSession $script:session -SampleCount 3 -IntervalSeconds 0

            Should -Invoke Get-DMPerformance -Times 3 -Exactly
        }

        It 'rejects unknown metric name' {
            $h = [OceanStorHost]::new([pscustomobject]@{ ID = 'HOST1' }, $script:session)
            { $h | Get-DMHostPerformance -WebSession $script:session -Metric 'NotAMetric' } | Should -Throw
        }
    }
}
