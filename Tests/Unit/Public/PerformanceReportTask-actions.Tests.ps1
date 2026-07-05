BeforeDiscovery {
    $script:testModule = New-Module -Name PerformanceReportTaskActionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData, [switch]$ApiV2) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }
        function Start-Sleep { param($Seconds) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformance.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Invoke-DMPerformanceReportTask.ps1"

        Export-ModuleMember -Function New-DMPerformanceReportTask, Get-DMPerformanceReportTask, Remove-DMPerformanceReportTask, `
            Invoke-DMPerformanceReportTask, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name PerformanceReportTaskActionsTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope PerformanceReportTaskActionsTestModule {
    Describe 'New-DMPerformanceReportTask' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }

            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data = [pscustomobject]@{
                        id      = 'task-01'
                        name    = 'lun-history'
                        content = @()
                    }
                }
            }
        }

        It 'POSTs to pms/report_task with the resolved object_type/object_id_list/indicator_list body' {
            $result = New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId '1', '2' -TimeSegment OneWeek -Metric TotalIOPS, AvgLatencyMs -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Resource -eq 'pms/report_task' -and
                $ApiV2 -eq $true -and
                $BodyData.name -eq 'lun-history' -and
                $BodyData.time_segment -eq 'one_week' -and
                $BodyData.content[0].object_type -eq 'LUN' -and
                (@($BodyData.content[0].object_id_list) -join ',') -eq '1,2' -and
                (@($BodyData.content[0].indicator_list)).Count -eq 2
            }

            $result.Id | Should -Be 'task-01'
        }

        It 'sets begin_time/end_time only when TimeSegment is Customer' {
            $start = Get-Date '2026-01-01T00:00:00Z'
            $end = Get-Date '2026-01-02T00:00:00Z'

            New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-custom' -ObjectType LUN -ObjectId '1' -TimeSegment Customer -StartTime $start -EndTime $end -Confirm:$false | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.begin_time -eq [System.DateTimeOffset]::new($start.ToUniversalTime()).ToUnixTimeSeconds() -and
                $BodyData.end_time -eq [System.DateTimeOffset]::new($end.ToUniversalTime()).ToUnixTimeSeconds()
            }
        }

        It 'throws when TimeSegment is Customer but StartTime/EndTime are not both supplied' {
            { New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-custom' -ObjectType LUN -ObjectId '1' -TimeSegment Customer -Confirm:$false } | Should -Throw '*StartTime*EndTime*'
        }

        It 'throws when EndTime is not after StartTime' {
            $start = Get-Date '2026-01-02T00:00:00Z'
            $end = Get-Date '2026-01-01T00:00:00Z'

            { New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-custom' -ObjectType LUN -ObjectId '1' -TimeSegment Customer -StartTime $start -EndTime $end -Confirm:$false } | Should -Throw '*EndTime must be later than StartTime*'
        }

        It 'defaults to the module default metric set when -Metric is omitted' {
            New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId '1' -TimeSegment OneWeek -Confirm:$false | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                (@($BodyData.content[0].indicator_list)).Count -eq $script:DMDefaultPerformanceMetrics.Count
            }
        }

        It 'does not call Invoke-DeviceManager when -WhatIf is specified' {
            New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId '1' -TimeSegment OneWeek -WhatIf | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }
    }

    Describe 'Get-DMPerformanceReportTask' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }

            Mock Invoke-DeviceManager {
                if ($Resource -match 'range=\[0-') {
                    return [pscustomobject]@{
                        data = @(
                            [pscustomobject]@{ id = '1'; name = 'lun-history'; content = @() }
                            [pscustomobject]@{ id = '2'; name = 'controller-daily'; content = @() }
                        )
                    }
                }
                return [pscustomobject]@{ data = @() }
            }
        }

        It 'GETs pms/report_task and returns every task as OceanstorPerformanceReportTask objects' {
            $result = @(Get-DMPerformanceReportTask -WebSession $script:session)

            $result.Count | Should -Be 2
            $result[0] | Should -BeOfType [OceanstorPerformanceReportTask]
            $result.Name | Should -Contain 'lun-history'

            Should -Invoke Invoke-DeviceManager -ParameterFilter {
                $Method -eq 'GET' -and $Resource -like 'pms/report_task*' -and $ApiV2 -eq $true
            }
        }

        It 'filters client-side by exact Id' {
            $result = @(Get-DMPerformanceReportTask -WebSession $script:session -Id '2')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'controller-daily'
        }

        It 'filters client-side by Name with wildcard support' {
            $result = @(Get-DMPerformanceReportTask -WebSession $script:session -Name 'lun*')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be '1'
        }

        It 'returns every task when Name/Id are omitted' {
            $result = @(Get-DMPerformanceReportTask -WebSession $script:session)

            $result.Count | Should -Be 2
        }
    }

    Describe 'Remove-DMPerformanceReportTask' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }

            Mock Invoke-DeviceManager {
                if ($Method -eq 'GET') {
                    if ($Resource -match 'range=\[0-') {
                        return [pscustomobject]@{
                            data = @(
                                [pscustomobject]@{ id = '1'; name = 'lun-history'; content = @() }
                            )
                        }
                    }
                    return [pscustomobject]@{ data = @() }
                }
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
            }
        }

        It 'DELETEs pms/report_task/{id} when resolved by Name' {
            Remove-DMPerformanceReportTask -Name 'lun-history' -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Resource -eq 'pms/report_task/1' -and $ApiV2 -eq $true
            }
        }

        It 'DELETEs pms/report_task/{id} when resolved by Id' {
            Remove-DMPerformanceReportTask -Id '1' -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Resource -eq 'pms/report_task/1' -and $ApiV2 -eq $true
            }
        }

        It 'does not call Invoke-DeviceManager DELETE when -WhatIf is specified' {
            Remove-DMPerformanceReportTask -Name 'lun-history' -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'rejects an unknown Name at parameter binding' {
            { Remove-DMPerformanceReportTask -Name 'does-not-exist' -Confirm:$false } | Should -Throw
        }
    }

    Describe 'Invoke-DMPerformanceReportTask' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
            $script:taskLogCallCount = 0

            Mock Start-Sleep { }

            Mock Invoke-DeviceManager {
                if ($Method -eq 'GET' -and $Resource -match '^pms/report_task\?range=') {
                    return [pscustomobject]@{
                        data = @([pscustomobject]@{ id = 'task-01'; name = 'lun-history'; content = @() })
                    }
                }
                if ($Method -eq 'GET' -and $Resource -match '^pms/report_task/task_log\?task_id=') {
                    $script:taskLogCallCount++
                    if ($script:taskLogCallCount -eq 1) {
                        return [pscustomobject]@{ data = @([pscustomobject]@{ id = 'log-00' }) }
                    }
                    return [pscustomobject]@{
                        data = @(
                            [pscustomobject]@{ id = 'log-00' }
                            [pscustomobject]@{ id = 'log-01'; task_id = 'task-01'; status = 'finished' }
                        )
                    }
                }
                if ($Method -eq 'GET' -and $Resource -match '^pms/report_task/export\?task_id=') {
                    return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
                }
                return [pscustomobject]@{ data = @() }
            }
        }

        It 'resolves the task by Name, triggers the export, and returns the new log entry' {
            $result = Invoke-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -PollIntervalSec 1 -TimeoutSec 30 -Confirm:$false

            $result.PSObject.TypeNames | Should -Contain 'OceanStor.PerformanceReportLog'
            $result.LogId | Should -Be 'log-01'
            $result.Status | Should -Be 'finished'

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Resource -eq 'pms/report_task/export?task_id=task-01'
            }
        }

        It 'resolves the task by Id' {
            $result = Invoke-DMPerformanceReportTask -WebSession $script:session -Id 'task-01' -PollIntervalSec 1 -TimeoutSec 30 -Confirm:$false

            $result.LogId | Should -Be 'log-01'
        }

        It 'does not trigger the export when -WhatIf is specified' {
            Invoke-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -WhatIf | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter {
                $Resource -match '^pms/report_task/export'
            }
        }

        It 'throws when no new log entry appears before the timeout' {
            Mock Invoke-DeviceManager {
                if ($Method -eq 'GET' -and $Resource -match '^pms/report_task\?range=') {
                    return [pscustomobject]@{
                        data = @([pscustomobject]@{ id = 'task-01'; name = 'lun-history'; content = @() })
                    }
                }
                if ($Method -eq 'GET' -and $Resource -match '^pms/report_task/task_log\?task_id=') {
                    return [pscustomobject]@{ data = @([pscustomobject]@{ id = 'log-00' }) }
                }
                if ($Method -eq 'GET' -and $Resource -match '^pms/report_task/export\?task_id=') {
                    return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
                }
                return [pscustomobject]@{ data = @() }
            }

            { Invoke-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -PollIntervalSec 1 -TimeoutSec 1 -Confirm:$false -ErrorAction Stop } | Should -Throw '*timed out*'
        }
    }
}
