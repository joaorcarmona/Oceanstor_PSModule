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

        It 'resolves NAS friendly names to documented file-system indicator IDs' {
            $script:map['Ops'].Id | Should -Be 182
            $script:map['ReadOps'].Id | Should -Be 232
            $script:map['WriteOps'].Id | Should -Be 233
            $script:map['AvgIOSizeKB'].Id | Should -Be 228
            $script:map['AvgReadOpsResponseTimeUs'].Id | Should -Be 524
            $script:map['AvgWriteOpsResponseTimeUs'].Id | Should -Be 525
            $script:map['NasServiceTimeUs'].Id | Should -Be 523
            $script:map['ReadBandwidthKBps'].Id | Should -Be 123
            $script:map['WriteBandwidthKBps'].Id | Should -Be 124
        }

        It 'keeps NAS response-time metrics in raw microseconds without a SourceUnit conversion' {
            foreach ($name in @('AvgReadOpsResponseTimeUs', 'AvgWriteOpsResponseTimeUs', 'NasServiceTimeUs')) {
                $script:map[$name].Unit | Should -Be 'us'
                $script:map[$name].ContainsKey('SourceUnit') | Should -BeFalse
            }
        }
    }

    Describe 'Get-DMPerformanceReportObjectTypeMap' {
        It 'maps every object type the module models for report tasks to its Name and Enum' {
            $map = Get-DMPerformanceReportObjectTypeMap
            $map['LUN'].Name | Should -Be 'LUN'
            $map['LUN'].Enum | Should -Be 11
            $map['Controller'].Name | Should -Be 'Controller'
            $map['Controller'].Enum | Should -Be 207
            $map['StoragePool'].Name | Should -Be 'StoragePool'
            $map['StoragePool'].Enum | Should -Be 216
            $map['Disk'].Name | Should -Be 'Disk'
            $map['Disk'].Enum | Should -Be 10
            $map['Host'].Name | Should -Be 'Host'
            $map['Host'].Enum | Should -Be 21
            $map['System'].Name | Should -Be 'System'
            $map['System'].Enum | Should -Be 201
            $map['FCPort'].Name | Should -Be 'FC_PORT'
            $map['FCPort'].Enum | Should -Be 212
            $map['EthernetPort'].Name | Should -Be 'ETH_PORT'
            $map['EthernetPort'].Enum | Should -Be 213
            $map['FileSystem'].Name | Should -Be 'FileSystem'
            $map['FileSystem'].Enum | Should -Be 40
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
