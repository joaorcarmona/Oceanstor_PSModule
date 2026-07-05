BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMControllerPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPerformance { param($WebSession, $ObjectType, $ObjectId, $Metric) }
        function Get-DMparsedElabel { param($eLabelString) [pscustomobject]@{} }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorController.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMControllerPerformance.ps1"

        Export-ModuleMember -Function Get-DMControllerPerformance, Get-DMPerformance, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMControllerPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMControllerPerformanceTestModule {
    Describe 'Get-DMControllerPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'batches all piped controller IDs into a single Get-DMPerformance call' {
            Mock Get-DMPerformance { }

            $ctrl1 = [OceanStorController]::new([pscustomobject]@{ ID = '0A'; TYPE = 207; ELABEL = 'x' }, $script:session)
            $ctrl2 = [OceanStorController]::new([pscustomobject]@{ ID = '0B'; TYPE = 207; ELABEL = 'x' }, $script:session)

            $ctrl1, $ctrl2 | Get-DMControllerPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'Controller' -and
                (@($ObjectId) -contains '0A') -and
                (@($ObjectId) -contains '0B')
            }
        }

        It 'passes -Metric through when supplied' {
            Mock Get-DMPerformance { }
            $ctrl = [OceanStorController]::new([pscustomobject]@{ ID = '0A'; TYPE = 207; ELABEL = 'x' }, $script:session)

            $ctrl | Get-DMControllerPerformance -WebSession $script:session -Metric TotalIOPS, AvgLatencyMs

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'TotalIOPS,AvgLatencyMs'
            }
        }

        It 'omits -Metric when not supplied' {
            Mock Get-DMPerformance { }
            $ctrl = [OceanStorController]::new([pscustomobject]@{ ID = '0A'; TYPE = 207; ELABEL = 'x' }, $script:session)

            $ctrl | Get-DMControllerPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $null -eq $Metric
            }
        }

        It 'calls Get-DMPerformance SampleCount times' {
            Mock Get-DMPerformance { }
            Mock Start-Sleep { }
            $ctrl = [OceanStorController]::new([pscustomobject]@{ ID = '0A'; TYPE = 207; ELABEL = 'x' }, $script:session)

            $ctrl | Get-DMControllerPerformance -WebSession $script:session -SampleCount 3 -IntervalSeconds 0

            Should -Invoke Get-DMPerformance -Times 3 -Exactly
        }

        It 'rejects unknown metric name' {
            $ctrl = [OceanStorController]::new([pscustomobject]@{ ID = '0A'; TYPE = 207; ELABEL = 'x' }, $script:session)
            { $ctrl | Get-DMControllerPerformance -WebSession $script:session -Metric 'NotAMetric' } | Should -Throw
        }
    }
}
