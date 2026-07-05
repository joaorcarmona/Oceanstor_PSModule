BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMStoragePoolPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPerformance { param($WebSession, $ObjectType, $ObjectId, $Metric) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorStoragePool.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMStoragePoolPerformance.ps1"

        Export-ModuleMember -Function Get-DMStoragePoolPerformance, Get-DMPerformance, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMStoragePoolPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMStoragePoolPerformanceTestModule {
    Describe 'Get-DMStoragePoolPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'batches all piped storage pool IDs into a single Get-DMPerformance call' {
            Mock Get-DMPerformance { }

            $pool1 = [OceanStorStoragePool]::new([pscustomobject]@{ ID = 'POOL1' }, $script:session)
            $pool2 = [OceanStorStoragePool]::new([pscustomobject]@{ ID = 'POOL2' }, $script:session)

            $pool1, $pool2 | Get-DMStoragePoolPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'StoragePool' -and
                (@($ObjectId) -contains 'POOL1') -and
                (@($ObjectId) -contains 'POOL2')
            }
        }

        It 'passes -Metric through when supplied' {
            Mock Get-DMPerformance { }
            $pool = [OceanStorStoragePool]::new([pscustomobject]@{ ID = 'POOL1' }, $script:session)

            $pool | Get-DMStoragePoolPerformance -WebSession $script:session -Metric TotalIOPS

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'TotalIOPS'
            }
        }

        It 'omits -Metric when not supplied' {
            Mock Get-DMPerformance { }
            $pool = [OceanStorStoragePool]::new([pscustomobject]@{ ID = 'POOL1' }, $script:session)

            $pool | Get-DMStoragePoolPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $null -eq $Metric
            }
        }

        It 'calls Get-DMPerformance SampleCount times' {
            Mock Get-DMPerformance { }
            Mock Start-Sleep { }
            $pool = [OceanStorStoragePool]::new([pscustomobject]@{ ID = 'POOL1' }, $script:session)

            $pool | Get-DMStoragePoolPerformance -WebSession $script:session -SampleCount 3 -IntervalSeconds 0

            Should -Invoke Get-DMPerformance -Times 3 -Exactly
        }

        It 'rejects unknown metric name' {
            $pool = [OceanStorStoragePool]::new([pscustomobject]@{ ID = 'POOL1' }, $script:session)
            { $pool | Get-DMStoragePoolPerformance -WebSession $script:session -Metric 'NotAMetric' } | Should -Throw
        }
    }
}
