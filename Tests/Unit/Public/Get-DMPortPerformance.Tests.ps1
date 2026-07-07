BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMPortPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPerformance { param($WebSession, $ObjectType, $ObjectId, $Metric) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorPortFc.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorPortEth.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPortBond.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPortPerformance.ps1"

        Export-ModuleMember -Function Get-DMPortPerformance, Get-DMPerformance, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMPortPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMPortPerformanceTestModule {
    Describe 'Get-DMPortPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'batches all piped FC port IDs into a single Get-DMPerformance call using FCPort ObjectType' {
            Mock Get-DMPerformance { }

            $p1 = [OceanStorPortFC]::new([pscustomobject]@{ ID = 'P0A' }, $script:session)
            $p2 = [OceanStorPortFC]::new([pscustomobject]@{ ID = 'P0B' }, $script:session)

            $p1, $p2 | Get-DMPortPerformance -WebSession $script:session -PortType FC

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'FCPort' -and
                (@($ObjectId) -contains 'P0A') -and
                (@($ObjectId) -contains 'P0B')
            }
        }

        It 'uses EthernetPort ObjectType for -PortType ETH' {
            Mock Get-DMPerformance { }

            $p = [OceanStorPortETH]::new([pscustomobject]@{ ID = 'ETH0A' }, $script:session)

            $p | Get-DMPortPerformance -WebSession $script:session -PortType ETH

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'EthernetPort' -and (@($ObjectId) -contains 'ETH0A')
            }
        }

        It 'uses BondPort ObjectType for -PortType Bond' {
            Mock Get-DMPerformance { }

            $p = [OceanStorPortBond]::new([pscustomobject]@{ ID = 'BOND0' }, $script:session)

            $p | Get-DMPortPerformance -WebSession $script:session -PortType Bond

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'BondPort' -and (@($ObjectId) -contains 'BOND0')
            }
        }

        It 'passes -Metric through when supplied' {
            Mock Get-DMPerformance { }
            $p = [OceanStorPortFC]::new([pscustomobject]@{ ID = 'P0A' }, $script:session)

            $p | Get-DMPortPerformance -WebSession $script:session -PortType FC -Metric TotalIOPS

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'TotalIOPS'
            }
        }

        It 'calls Get-DMPerformance SampleCount times' {
            Mock Get-DMPerformance { }
            Mock Start-Sleep { }
            $p = [OceanStorPortFC]::new([pscustomobject]@{ ID = 'P0A' }, $script:session)

            $p | Get-DMPortPerformance -WebSession $script:session -PortType FC -SampleCount 3 -IntervalSeconds 0

            Should -Invoke Get-DMPerformance -Times 3 -Exactly
        }

        It 'rejects unknown metric name' {
            $p = [OceanStorPortFC]::new([pscustomobject]@{ ID = 'P0A' }, $script:session)
            { $p | Get-DMPortPerformance -WebSession $script:session -PortType FC -Metric 'NotAMetric' } | Should -Throw
        }

        It 'rejects an unsupported -PortType' {
            { [OceanStorPortFC]::new([pscustomobject]@{ ID = 'P0A' }, $script:session) | Get-DMPortPerformance -WebSession $script:session -PortType FCoE } | Should -Throw
        }
    }
}
