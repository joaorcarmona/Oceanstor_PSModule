BeforeDiscovery {
    $script:testModule = New-Module -Name ReportTaskClassTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function global:Remove-DMPerformanceReportTask {
            param([pscustomobject]$WebSession, [string]$Id)
            $global:RemovalInvocation = [pscustomobject]@{ Type = 'PerformanceReportTask'; Name = $Id; WebSession = $WebSession }
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceReportTask.ps1"

        Export-ModuleMember -Function New-DMPerformanceReportLog
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name ReportTaskClassTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope ReportTaskClassTestModule {
    Describe 'OceanstorPerformanceReportTask' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
        }

        It 'maps raw fields into typed properties' {
            $raw = [pscustomobject]@{
                id               = 'task-01'
                name             = 'lun-history'
                language         = 'en'
                retention_number = '5'
                format           = 'CSV'
                time_segment     = 'customer'
                begin_time       = 1700000000
                end_time         = 1700003600
                content          = @(
                    [pscustomobject]@{
                        report_type    = 'performance'
                        compute_mode   = 'avg'
                        object_type    = 'LUN'
                        object_id_list = @('1', '2')
                        indicator_list = @('21', '22')
                    }
                )
            }

            $task = [OceanstorPerformanceReportTask]::new($raw, $script:session)

            $task.Id | Should -Be 'task-01'
            $task.Name | Should -Be 'lun-history'
            $task.Language | Should -Be 'en'
            $task.Format | Should -Be 'CSV'
            $task.Begin | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1700000000).UtcDateTime)
            $task.End | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1700003600).UtcDateTime)
            $task.Contents.Count | Should -Be 1
            $task.Contents[0].ReportType | Should -Be 'performance'
            $task.Contents[0].ObjectType | Should -Be 'LUN'
            $task.Contents[0].ObjectIdList | Should -Be @('1', '2')
            $task.Contents[0].IndicatorList | Should -Be @('21', '22')
        }

        It 'defaults Begin/End when begin_time/end_time are absent' {
            $raw = [pscustomobject]@{
                id       = 'task-02'
                name     = 'lun-weekly'
                content  = @()
            }

            $task = [OceanstorPerformanceReportTask]::new($raw, $script:session)

            $task.Begin | Should -Be ([datetime]::MinValue)
            $task.End | Should -Be ([datetime]::MinValue)
        }

        It 'Delete() forwards to Remove-DMPerformanceReportTask with its own Id/Session' {
            $raw = [pscustomobject]@{ id = 'task-01'; name = 'lun-history'; content = @() }
            $task = [OceanstorPerformanceReportTask]::new($raw, $script:session)

            $task.Delete() | Out-Null

            $global:RemovalInvocation.Type | Should -Be 'PerformanceReportTask'
            $global:RemovalInvocation.Name | Should -Be 'task-01'
            $global:RemovalInvocation.WebSession | Should -Be $script:session
        }
    }

    Describe 'New-DMPerformanceReportLog' {
        It 'builds a PSTypeName-tagged log object with a default display set' {
            $raw = [pscustomobject]@{ id = 'log-01'; task_id = 'task-01'; status = 'finished' }

            $log = New-DMPerformanceReportLog -Raw $raw -Session ([pscustomobject]@{ hostname = 'array01' })

            $log.PSObject.TypeNames | Should -Contain 'OceanStor.PerformanceReportLog'
            $log.LogId | Should -Be 'log-01'
            $log.TaskId | Should -Be 'task-01'
            $log.Status | Should -Be 'finished'
            $log.Raw | Should -Be $raw
            $log.Session.hostname | Should -Be 'array01'
        }
    }
}
