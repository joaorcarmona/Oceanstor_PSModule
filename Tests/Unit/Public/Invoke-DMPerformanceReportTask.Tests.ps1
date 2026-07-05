BeforeDiscovery {
    $script:testModule = New-Module -Name InvokeDMPerformanceReportTaskTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData, [switch]$ApiV2) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Invoke-DMPerformanceReportTask.ps1"

        Export-ModuleMember -Function Invoke-DMPerformanceReportTask, Get-DMPerformanceReportTask
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name InvokeDMPerformanceReportTaskTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope InvokeDMPerformanceReportTaskTestModule {
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
