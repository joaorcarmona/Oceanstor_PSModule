BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMLunPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPerformance { param($WebSession, $ObjectType, $ObjectId, $Metric) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv3.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv6.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMLunPerformance.ps1"

        Export-ModuleMember -Function Get-DMLunPerformance, Get-DMPerformance, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMLunPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMLunPerformanceTestModule {
    Describe 'Get-DMLunPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'batches all piped v3 LUN IDs into a single Get-DMPerformance call' {
            Mock Get-DMPerformance { }

            $lun1 = [OceanstorLunv3]::new([pscustomobject]@{ ID = 'LUN1' }, $script:session)
            $lun2 = [OceanstorLunv3]::new([pscustomobject]@{ ID = 'LUN2' }, $script:session)

            $lun1, $lun2 | Get-DMLunPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'LUN' -and
                (@($ObjectId) -contains 'LUN1') -and
                (@($ObjectId) -contains 'LUN2')
            }
        }

        It 'accepts v6 LUN objects too' {
            Mock Get-DMPerformance { }

            $lun = [OceanstorLunv6]::new([pscustomobject]@{ ID = 'LUN3' }, $script:session)

            $lun | Get-DMLunPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'LUN' -and (@($ObjectId) -contains 'LUN3')
            }
        }

        It 'passes -Metric through when supplied' {
            Mock Get-DMPerformance { }
            $lun = [OceanstorLunv3]::new([pscustomobject]@{ ID = 'LUN1' }, $script:session)

            $lun | Get-DMLunPerformance -WebSession $script:session -Metric TotalIOPS

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'TotalIOPS'
            }
        }

        It 'omits -Metric when not supplied' {
            Mock Get-DMPerformance { }
            $lun = [OceanstorLunv3]::new([pscustomobject]@{ ID = 'LUN1' }, $script:session)

            $lun | Get-DMLunPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $null -eq $Metric
            }
        }

        It 'calls Get-DMPerformance SampleCount times' {
            Mock Get-DMPerformance { }
            Mock Start-Sleep { }
            $lun = [OceanstorLunv3]::new([pscustomobject]@{ ID = 'LUN1' }, $script:session)

            $lun | Get-DMLunPerformance -WebSession $script:session -SampleCount 3 -IntervalSeconds 0

            Should -Invoke Get-DMPerformance -Times 3 -Exactly
        }

        It 'rejects unknown metric name' {
            $lun = [OceanstorLunv3]::new([pscustomobject]@{ ID = 'LUN1' }, $script:session)
            { $lun | Get-DMLunPerformance -WebSession $script:session -Metric 'NotAMetric' } | Should -Throw
        }

        It 'rejects an InputObject that is neither OceanstorLunv3 nor OceanstorLunv6' {
            $notALun = [pscustomobject]@{ Id = 'LUN1' }
            { $notALun | Get-DMLunPerformance -WebSession $script:session } | Should -Throw
        }
    }
}
