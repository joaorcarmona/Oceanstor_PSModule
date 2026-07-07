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

        It 'POSTs to pms/report_task with the documented performance content body' {
            $result = New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId '1', '2' -TimeSegment OneWeek -Metric TotalIOPS, AvgLatencyMs -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Resource -eq 'pms/report_task' -and
                $ApiV2 -eq $true -and
                $BodyData.name -eq 'lun-history' -and
                $BodyData.time_segment -eq 'one_week' -and
                $BodyData.content[0].report_type -eq 'performance' -and
                $BodyData.content[0].compute_mode -eq 'avg' -and
                $BodyData.content[0].object_type -eq 'LUN' -and
                $BodyData.content[0].object_type_enum -eq 11 -and
                $BodyData.content[0].sort_entities -eq 'customer' -and
                $BodyData.frequency -eq 'day' -and
                $BodyData.run_time.hour -eq 0 -and
                $BodyData.run_time.min -eq 0 -and
                (@($BodyData.content[0].entities)).Count -eq 2 -and
                (@($BodyData.content[0].entities | ForEach-Object { $_.id }) -join ',') -eq '1,2' -and
                $BodyData.content[0].entities[0].name -eq '1' -and
                $BodyData.content[0].entities[0].data -eq '{"ID":"1","NAME":"1"}' -and
                (@($BodyData.content[0].indicators.basic)).Count -eq 2 -and
                (@($BodyData.content[0].indicators.advance)).Count -eq 0 -and
                $BodyData.content[0].sort_indicator -eq $BodyData.content[0].indicators.basic[0] -and
                $BodyData.content[0].sort_type -eq 'top' -and
                $BodyData.content[0].limit -eq 5
            }

            $result.Id | Should -Be 'task-01'
        }

        It 'uses NAS default metrics and object type 40 for FileSystem when -Metric is omitted' {
            New-DMPerformanceReportTask -WebSession $script:session -Name 'fs-history' -ObjectType FileSystem -ObjectId '1' -TimeSegment OneWeek -Confirm:$false | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.content[0].object_type -eq 'FileSystem' -and
                $BodyData.content[0].object_type_enum -eq 40 -and
                (@($BodyData.content[0].indicators.basic)).Count -eq $script:DMDefaultNasPerformanceMetrics.Count
            }
        }

        It 'sends a capacity content block with empty indicators and no performance-only fields' {
            New-DMPerformanceReportTask -WebSession $script:session -Name 'pool-capacity' -ObjectType StoragePool -ObjectId '0' -TimeSegment OneWeek -ReportType Capacity -Confirm:$false | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.content[0].report_type -eq 'capacity' -and
                $BodyData.content[0].object_type -eq 'STORAGEPOOL' -and
                $BodyData.content[0].object_type_enum -eq 216 -and
                (@($BodyData.content[0].indicators.basic)).Count -eq 0 -and
                (@($BodyData.content[0].indicators.advance)).Count -eq 0 -and
                (-not $BodyData.content[0].ContainsKey('compute_mode')) -and
                (-not $BodyData.content[0].ContainsKey('sort_indicator')) -and
                (-not $BodyData.content[0].ContainsKey('sort_type')) -and
                (-not $BodyData.content[0].ContainsKey('limit'))
            }
        }

        It 'picks limit 10 when the entity count is between 6 and 10' {
            New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId @(1..6 | ForEach-Object { "$_" }) -TimeSegment OneWeek -Confirm:$false | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.content[0].limit -eq 10
            }
        }

        It 'picks limit 16 when the entity count is between 11 and 16' {
            New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId @(1..11 | ForEach-Object { "$_" }) -TimeSegment OneWeek -Confirm:$false | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.content[0].limit -eq 16
            }
        }

        It 'throws when more than 16 object IDs are supplied without -Force' {
            { New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId @(1..17 | ForEach-Object { "$_" }) -TimeSegment OneWeek -Confirm:$false } | Should -Throw '*Use -Force*'

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'warns and submits with limit 16 when more than 16 object IDs are supplied with -Force' {
            New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId @(1..17 | ForEach-Object { "$_" }) -TimeSegment OneWeek -Force -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.content[0].limit -eq 16 -and
                (@($BodyData.content[0].entities)).Count -eq 17
            }
        }

        It 'sets begin_time/end_time only when TimeSegment is Customer' {
            $start = Get-Date '2026-01-01T00:00:00Z'
            $end = Get-Date '2026-01-02T00:00:00Z'

            New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-custom' -ObjectType LUN -ObjectId '1' -TimeSegment Customer -StartTime $start -EndTime $end -Confirm:$false | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $BodyData.begin_time -eq [System.DateTimeOffset]::new($start.ToUniversalTime()).ToUnixTimeMilliseconds() -and
                $BodyData.end_time -eq [System.DateTimeOffset]::new($end.ToUniversalTime()).ToUnixTimeMilliseconds()
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
                (@($BodyData.content[0].indicators.basic)).Count -eq $script:DMDefaultPerformanceMetrics.Count
            }
        }

        It 'does not call Invoke-DeviceManager when -WhatIf is specified' {
            New-DMPerformanceReportTask -WebSession $script:session -Name 'lun-history' -ObjectType LUN -ObjectId '1' -TimeSegment OneWeek -WhatIf | Out-Null

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }
    }
}
