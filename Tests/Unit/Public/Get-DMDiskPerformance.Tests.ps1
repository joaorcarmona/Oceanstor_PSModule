BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMDiskPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPerformance { param($WebSession, $ObjectType, $ObjectId, $Metric) }
        function Get-DMparsedElabel { param($eLabelString) [pscustomobject]@{} }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorDisks.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMDiskPerformance.ps1"

        Export-ModuleMember -Function Get-DMDiskPerformance, Get-DMPerformance, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMDiskPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMDiskPerformanceTestModule {
    Describe 'Get-DMDiskPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'batches all piped disk IDs into a single Get-DMPerformance call' {
            Mock Get-DMPerformance { }

            $disk1 = [OceanStorDisks]::new([pscustomobject]@{ ID = 'DAE001'; TYPE = 10; BARCODE = 'AB1234567890'; ELABEL = 'x' }, $script:session)
            $disk2 = [OceanStorDisks]::new([pscustomobject]@{ ID = 'DAE002'; TYPE = 10; BARCODE = 'AB1234567890'; ELABEL = 'x' }, $script:session)

            $disk1, $disk2 | Get-DMDiskPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'Disk' -and
                (@($ObjectId) -contains 'DAE001') -and
                (@($ObjectId) -contains 'DAE002')
            }
        }

        It 'passes -Metric through when supplied' {
            Mock Get-DMPerformance { }
            $disk = [OceanStorDisks]::new([pscustomobject]@{ ID = 'DAE001'; TYPE = 10; BARCODE = 'AB1234567890'; ELABEL = 'x' }, $script:session)

            $disk | Get-DMDiskPerformance -WebSession $script:session -Metric TotalIOPS

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'TotalIOPS'
            }
        }

        It 'omits -Metric when not supplied' {
            Mock Get-DMPerformance { }
            $disk = [OceanStorDisks]::new([pscustomobject]@{ ID = 'DAE001'; TYPE = 10; BARCODE = 'AB1234567890'; ELABEL = 'x' }, $script:session)

            $disk | Get-DMDiskPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $null -eq $Metric
            }
        }

        It 'calls Get-DMPerformance SampleCount times' {
            Mock Get-DMPerformance { }
            Mock Start-Sleep { }
            $disk = [OceanStorDisks]::new([pscustomobject]@{ ID = 'DAE001'; TYPE = 10; BARCODE = 'AB1234567890'; ELABEL = 'x' }, $script:session)

            $disk | Get-DMDiskPerformance -WebSession $script:session -SampleCount 3 -IntervalSeconds 0

            Should -Invoke Get-DMPerformance -Times 3 -Exactly
        }

        It 'rejects unknown metric name' {
            $disk = [OceanStorDisks]::new([pscustomobject]@{ ID = 'DAE001'; TYPE = 10; BARCODE = 'AB1234567890'; ELABEL = 'x' }, $script:session)
            { $disk | Get-DMDiskPerformance -WebSession $script:session -Metric 'NotAMetric' } | Should -Throw
        }
    }
}
