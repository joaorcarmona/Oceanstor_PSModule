BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMCapacityHistoryTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function New-DMPerformanceReportTask { param($WebSession, $Name, $ReportType, $TimeSegment, $StartTime, $EndTime, $Format, $RetentionNumber, $ObjectType, $ObjectId, [switch]$Confirm) }
        function Invoke-DMPerformanceReportTask { param($WebSession, $Id, $TimeoutSec, [switch]$Confirm) }
        function Save-DMPerformanceReportFile { param($WebSession, $LogId, $Path, [switch]$Force) }
        function Import-DMPerformanceReportCsv { param($ZipPath) }
        function Remove-DMPerformanceReportTask { param($WebSession, $Id, [switch]$Confirm) }
        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, [switch]$ApiV2) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceSample.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMCapacityHistory.ps1"

        Export-ModuleMember -Function Get-DMCapacityHistory, New-DMPerformanceReportTask, Invoke-DMPerformanceReportTask, `
            Save-DMPerformanceReportFile, Import-DMPerformanceReportCsv, Invoke-DeviceManager, New-DMPerformanceSample
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMCapacityHistoryTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMCapacityHistoryTestModule {
    Describe 'Get-DMCapacityHistory' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
            $script:callOrder = [System.Collections.Generic.List[string]]::new()

            Mock New-DMPerformanceReportTask {
                $script:callOrder.Add('New-DMPerformanceReportTask')
                [pscustomobject]@{ Id = 'task-01'; Name = $Name }
            }
            Mock Invoke-DMPerformanceReportTask {
                $script:callOrder.Add('Invoke-DMPerformanceReportTask')
                [pscustomobject]@{ LogId = 'log-01'; TaskId = $Id; Status = 'finished' }
            }
            Mock Save-DMPerformanceReportFile {
                $script:callOrder.Add('Save-DMPerformanceReportFile')
            }
            Mock Import-DMPerformanceReportCsv {
                $script:callOrder.Add('Import-DMPerformanceReportCsv')
                @(
                    [pscustomobject]@{ 'Object ID' = '0'; 'Time' = '1700000000'; 'Total Capacity(GB)' = '1024.5'; 'Pool Name' = 'pool0'; SourceFile = 'capacity.csv' }
                )
            }
            Mock Remove-DMPerformanceReportTask {
                $script:callOrder.Add('Remove-DMPerformanceReportTask')
            }
            Mock Invoke-DeviceManager {
                $script:callOrder.Add('Invoke-DeviceManager')
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
            }
        }

        It 'is available as a command with no -Metric parameter (capacity needs no performance metrics)' {
            $command = Get-Command Get-DMCapacityHistory
            $command | Should -Not -BeNullOrEmpty
            $command.Parameters.ContainsKey('Metric') | Should -BeFalse
        }

        It 'accepts ObjectType System' {
            { Get-DMCapacityHistory -WebSession $script:session -ObjectType System -ObjectId '1' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) } | Should -Not -Throw
        }

        It 'accepts ObjectType StoragePool' {
            { Get-DMCapacityHistory -WebSession $script:session -ObjectType StoragePool -ObjectId '0' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) } | Should -Not -Throw
        }

        It 'rejects performance-only object types at parameter binding' {
            foreach ($badType in @('LUN', 'FileSystem', 'Disk', 'Controller', 'Host', 'FCPort', 'EthernetPort')) {
                { Get-DMCapacityHistory -WebSession $script:session -ObjectType $badType -ObjectId '1' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) } | Should -Throw
            }
        }

        It 'creates the report task with -ReportType Capacity and no performance metrics' {
            Get-DMCapacityHistory -WebSession $script:session -ObjectType StoragePool -ObjectId '0' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) | Out-Null

            Should -Invoke New-DMPerformanceReportTask -Times 1 -Exactly -ParameterFilter {
                $ReportType -eq 'Capacity' -and
                $ObjectType -eq 'StoragePool' -and
                $TimeSegment -eq 'Customer' -and
                $Format -eq 'CSV'
            }
        }

        It 'runs the full create -> run -> download -> parse -> cleanup pipeline in order' {
            $result = Get-DMCapacityHistory -WebSession $script:session -ObjectType StoragePool -ObjectId '0' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)

            $script:callOrder | Should -Be @(
                'New-DMPerformanceReportTask',
                'Invoke-DMPerformanceReportTask',
                'Save-DMPerformanceReportFile',
                'Import-DMPerformanceReportCsv',
                'Invoke-DeviceManager',
                'Remove-DMPerformanceReportTask'
            )

            $result.Count | Should -Be 1
        }

        It 'parses capacity CSV rows by header into sample properties' {
            $result = Get-DMCapacityHistory -WebSession $script:session -ObjectType StoragePool -ObjectId '0' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)

            $result[0].ObjectId | Should -Be '0'
            $result[0].Timestamp | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1700000000).UtcDateTime)
            $result[0].'Total Capacity(GB)' | Should -Be 1024.5
            $result[0].'Pool Name' | Should -Be 'pool0'
            $result[0].ObjectType | Should -Be 'StoragePool'
        }

        It 'accumulates piped ObjectId values before creating a single report task' {
            '0', '1' | Get-DMCapacityHistory -WebSession $script:session -ObjectType StoragePool -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) | Out-Null

            Should -Invoke New-DMPerformanceReportTask -Times 1 -Exactly -ParameterFilter {
                (@($ObjectId) -join ',') -eq '0,1'
            }
        }

        It 'returns an empty ArrayList and makes no calls when no ObjectId is supplied' {
            $result = @() | Get-DMCapacityHistory -WebSession $script:session -ObjectType System -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)

            @($result).Count | Should -Be 0
            Should -Invoke New-DMPerformanceReportTask -Times 0 -Exactly
        }

        It 'skips cleanup when -KeepReportTask is specified' {
            Get-DMCapacityHistory -WebSession $script:session -ObjectType StoragePool -ObjectId '0' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -KeepReportTask | Out-Null

            Should -Invoke Remove-DMPerformanceReportTask -Times 0 -Exactly
            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'still cleans up the report task even when parsing throws' {
            Mock Import-DMPerformanceReportCsv { throw 'boom' }

            { Get-DMCapacityHistory -WebSession $script:session -ObjectType StoragePool -ObjectId '0' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -ErrorAction Stop } | Should -Throw '*boom*'

            Should -Invoke Remove-DMPerformanceReportTask -Times 1 -Exactly
        }

        It 'passes -TimeoutSec through to the report task run' {
            Get-DMCapacityHistory -WebSession $script:session -ObjectType StoragePool -ObjectId '0' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -TimeoutSec 300 | Out-Null

            Should -Invoke Invoke-DMPerformanceReportTask -Times 1 -Exactly -ParameterFilter {
                $TimeoutSec -eq 300
            }
        }
    }
}
