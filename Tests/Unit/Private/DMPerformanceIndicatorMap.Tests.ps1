BeforeDiscovery {
    $script:testModule = New-Module -Name DMPerformanceIndicatorMapTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"

        Export-ModuleMember -Function Get-DMPerformanceIndicatorMap, Get-DMPerformanceReportObjectTypeMap, Get-DMPerformanceReportTimeSegmentMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name DMPerformanceIndicatorMapTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope DMPerformanceIndicatorMapTestModule {
    Describe 'Get-DMPerformanceIndicatorMap' {
        BeforeEach {
            $script:map = Get-DMPerformanceIndicatorMap
        }

        It 'contains every friendly name expected by Phase 1' {
            $expectedNames = @(
                'TotalIOPS', 'ReadIOPS', 'WriteIOPS',
                'BandwidthMBps', 'ReadBandwidthMBps', 'WriteBandwidthMBps',
                'AvgLatencyMs', 'ReadLatencyMs', 'WriteLatencyMs',
                'AvgLatencyUs', 'ReadLatencyUs', 'WriteLatencyUs',
                'ServiceTimeUs', 'AvgReadIOSizeKB', 'AvgWriteIOSizeKB',
                'QueueLength', 'UsagePercent', 'ReadCacheHitPercent',
                'WriteCacheHitPercent', 'CpuUsagePercent', 'CacheUsagePercent'
            )
            foreach ($name in $expectedNames) {
                $script:map.Contains($name) | Should -BeTrue -Because "the map should have an entry for '$name'"
            }
        }

        It 'maps each entry to an integer Id and a non-empty Unit' {
            foreach ($name in $script:map.Keys) {
                $script:map[$name].Id | Should -BeOfType [int]
                $script:map[$name].Unit | Should -Not -BeNullOrEmpty
            }
        }

        It 'resolves known friendly names to their documented indicator IDs' {
            $script:map['TotalIOPS'].Id | Should -Be 22
            $script:map['ReadIOPS'].Id | Should -Be 25
            $script:map['WriteIOPS'].Id | Should -Be 28
            $script:map['BandwidthMBps'].Id | Should -Be 21
            $script:map['AvgLatencyMs'].Id | Should -Be 370
            $script:map['ReadLatencyMs'].Id | Should -Be 384
            $script:map['WriteLatencyMs'].Id | Should -Be 385
            $script:map['QueueLength'].Id | Should -Be 19
            $script:map['UsagePercent'].Id | Should -Be 18
        }

        It 'marks microsecond-sourced Ms variants with SourceUnit us' {
            $script:map['AvgLatencyMs'].SourceUnit | Should -Be 'us'
            $script:map['AvgLatencyMs'].Unit | Should -Be 'ms'
        }

        It 'is queryable and returns a fresh copy on each call' {
            $second = Get-DMPerformanceIndicatorMap
            $second['TotalIOPS'].Id | Should -Be $script:map['TotalIOPS'].Id
        }
    }

    Describe 'Get-DMPerformanceReportObjectTypeMap' {
        It 'maps every object type the module models for report tasks' {
            $map = Get-DMPerformanceReportObjectTypeMap
            $map['LUN'] | Should -Be 'LUN'
            $map['Controller'] | Should -Be 'CONTROLLER'
            $map['StoragePool'] | Should -Be 'STORAGEPOOL'
            $map['Disk'] | Should -Be 'DISK'
            $map['Host'] | Should -Be 'HOST'
            $map['System'] | Should -Be 'SYSTEM'
            $map['FCPort'] | Should -Be 'FC_PORT'
            $map['EthernetPort'] | Should -Be 'ETH_PORT'
        }
    }

    Describe 'Get-DMPerformanceReportTimeSegmentMap' {
        It 'maps every friendly time segment to its API string' {
            $map = Get-DMPerformanceReportTimeSegmentMap
            $map['OneHour'] | Should -Be 'one_hour'
            $map['OneDay'] | Should -Be 'one_day'
            $map['OneWeek'] | Should -Be 'one_week'
            $map['OneMonth'] | Should -Be 'one_month'
            $map['OneYear'] | Should -Be 'one_year'
            $map['Customer'] | Should -Be 'customer'
        }
    }
}
