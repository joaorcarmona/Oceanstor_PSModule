BeforeDiscovery {
    $script:testModule = New-Module -Name NewDMPerformanceReportTaskTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData, [switch]$ApiV2) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\DMPerformanceIndicatorMap.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformance.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMPerformanceReportTask.ps1"

        Export-ModuleMember -Function New-DMPerformanceReportTask, Get-DMPerformanceIndicatorMap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name NewDMPerformanceReportTaskTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewDMPerformanceReportTaskTestModule {
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
}
