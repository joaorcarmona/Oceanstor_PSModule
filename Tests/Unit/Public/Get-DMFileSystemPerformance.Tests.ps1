BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMFileSystemPerformanceTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPerformance { param($WebSession, $ObjectType, $ObjectId, $Metric) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorFileSystem.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMFileSystemPerformance.ps1"

        Export-ModuleMember -Function Get-DMFileSystemPerformance, Get-DMPerformance, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMFileSystemPerformanceTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMFileSystemPerformanceTestModule {
    Describe 'Get-DMFileSystemPerformance' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'batches all piped file system IDs into a single Get-DMPerformance call' {
            Mock Get-DMPerformance { }

            $fs1 = [OceanstorFileSystem]::new([pscustomobject]@{ ID = 'FS1'; SECTORSIZE = 512; ALLOCCAPACITY = '0' }, $script:session)
            $fs2 = [OceanstorFileSystem]::new([pscustomobject]@{ ID = 'FS2'; SECTORSIZE = 512; ALLOCCAPACITY = '0' }, $script:session)

            $fs1, $fs2 | Get-DMFileSystemPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $ObjectType -eq 'FileSystem' -and
                (@($ObjectId) -contains 'FS1') -and
                (@($ObjectId) -contains 'FS2')
            }
        }

        It 'passes an explicit Metric list through to Get-DMPerformance' {
            Mock Get-DMPerformance { }

            $fs = [OceanstorFileSystem]::new([pscustomobject]@{ ID = 'FS1'; SECTORSIZE = 512; ALLOCCAPACITY = '0' }, $script:session)

            $fs | Get-DMFileSystemPerformance -WebSession $script:session -Metric Ops

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                (@($Metric) -join ',') -eq 'Ops'
            }
        }

        It 'omits Metric so Get-DMPerformance applies its NAS defaults when -Metric is not specified' {
            Mock Get-DMPerformance { }

            $fs = [OceanstorFileSystem]::new([pscustomobject]@{ ID = 'FS1'; SECTORSIZE = 512; ALLOCCAPACITY = '0' }, $script:session)

            $fs | Get-DMFileSystemPerformance -WebSession $script:session

            Should -Invoke Get-DMPerformance -Times 1 -Exactly -ParameterFilter {
                $null -eq $Metric
            }
        }

        It 'takes SampleCount samples through repeated Get-DMPerformance calls' {
            Mock Get-DMPerformance { }

            $fs = [OceanstorFileSystem]::new([pscustomobject]@{ ID = 'FS1'; SECTORSIZE = 512; ALLOCCAPACITY = '0' }, $script:session)

            $fs | Get-DMFileSystemPerformance -WebSession $script:session -SampleCount 3 -IntervalSeconds 0

            Should -Invoke Get-DMPerformance -Times 3 -Exactly
        }

        It 'rejects an unknown metric name' {
            $fs = [OceanstorFileSystem]::new([pscustomobject]@{ ID = 'FS1'; SECTORSIZE = 512; ALLOCCAPACITY = '0' }, $script:session)
            { $fs | Get-DMFileSystemPerformance -WebSession $script:session -Metric 'NotAMetric' } | Should -Throw
        }

        It 'rejects an InputObject that is not an OceanstorFileSystem' {
            $notAFs = [pscustomobject]@{ Id = 'FS1' }
            { $notAFs | Get-DMFileSystemPerformance -WebSession $script:session } | Should -Throw
        }
    }
}
