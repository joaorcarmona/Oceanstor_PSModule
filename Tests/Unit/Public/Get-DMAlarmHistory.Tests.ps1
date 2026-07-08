BeforeDiscovery {
    $script:alarmHistoryModule = New-Module -Name AlarmHistoryTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [int]$TimeoutSec,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorAlarm.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMAlarmType.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMAlarmHistory.ps1"

        Export-ModuleMember -Function 'Get-DMAlarmHistory', 'Get-DMAlarmType'
    }

    Import-Module $script:alarmHistoryModule -Force
}

AfterAll {
    Remove-Module -Name AlarmHistoryTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope AlarmHistoryTestModule {
    Describe 'Get-DMAlarmHistory' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001' }
            $script:resources = New-Object System.Collections.Generic.List[string]

            # One historical alarm sample; time fields = 0 so the class takes the
            # non-timespan branch, and level 6 exercises the corrected mapping.
            $script:sampleAlarm = [pscustomobject]@{
                alarmObjType = '10'; clearName = ''; clearTime = 0; confirmTime = 0
                description = 'disk fault'; detail = ''; eventID = 1; eventParam = ''
                location = 'DISK00'; name = 'Disk Fault'; recoverTime = 0; sequence = 42
                sourceID = ''; sourceType = ''; startTime = 0; strEventID = '0x1'
                suggestion = 'N/A'; alarmStatus = 1; level = 6; type = 1; eventType = 1
            }

            # Records every composed Resource and answers both the alarm-type
            # catalog lookup and the history query.
            Mock Invoke-DeviceManager {
                $script:resources.Add($Resource)
                if ($Resource -like 'ALARM_DEFINITION_OBJ*') {
                    [pscustomobject]@{
                        error = [pscustomobject]@{ Code = 0 }
                        data  = @(
                            [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'disk'; CMO_ALARM_OBJ_TYPE = '10'; ID = '1' }
                            [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'LUN'; CMO_ALARM_OBJ_TYPE = '11'; ID = '2' }
                        )
                    }
                }
                else {
                    [pscustomobject]@{
                        error = [pscustomobject]@{ Code = 0 }
                        data  = @($script:sampleAlarm)
                    }
                }
            }
        }

        It 'always sorts newest-first and returns OceanStorAlarm objects with corrected Level' {
            $result = @(Get-DMAlarmHistory -WebSession $script:session)

            $result.Count | Should -Be 1
            $result[0].GetType().Name | Should -Be 'OceanStorAlarm'
            $result[0].Level | Should -Be 'critical'
            $historyResource = $script:resources | Where-Object { $_ -like 'alarm/historyalarm*' } | Select-Object -First 1
            $historyResource | Should -BeLike '*sortby=startTime,d*'
            $historyResource | Should -Not -BeLike '*filter=*'
        }

        It 'maps -Level Critical and -Type Alarm to the documented enum values' {
            $null = Get-DMAlarmHistory -WebSession $script:session -Level Critical -Type Alarm

            $historyResource = $script:resources | Where-Object { $_ -like 'alarm/historyalarm*' } | Select-Object -First 1
            $historyResource | Should -Match 'level::6'
            $historyResource | Should -Match 'type::1'
            $historyResource | Should -Match 'level::6 and type::1'
        }

        It 'maps -AlarmStatus Cleared to alarmStatus::2' {
            $null = Get-DMAlarmHistory -WebSession $script:session -AlarmStatus Cleared

            $historyResource = $script:resources | Where-Object { $_ -like 'alarm/historyalarm*' } | Select-Object -First 1
            $historyResource | Should -Match 'alarmStatus::2'
        }

        It 'maps -Type SecurityLog to type::10' {
            $null = Get-DMAlarmHistory -WebSession $script:session -Type SecurityLog

            $historyResource = $script:resources | Where-Object { $_ -like 'alarm/historyalarm*' } | Select-Object -First 1
            $historyResource | Should -Match 'type::10'
        }

        It 'resolves -AlarmObjectType name to its numeric value via the catalog' {
            $null = Get-DMAlarmHistory -WebSession $script:session -AlarmObjectType disk

            # The name is resolved from Get-DMAlarmType's internal list, so the
            # object-type catalog endpoint is not queried.
            ($script:resources | Where-Object { $_ -like 'ALARM_DEFINITION_OBJ*' }).Count | Should -Be 0
            $historyResource = $script:resources | Where-Object { $_ -like 'alarm/historyalarm*' } | Select-Object -First 1
            $historyResource | Should -Match 'alarmObjType::10'
        }

        It 'throws a clear error for an unknown -AlarmObjectType name' {
            { Get-DMAlarmHistory -WebSession $script:session -AlarmObjectType nope } |
                Should -Throw "*Unknown alarm object type 'nope'*"
        }

        It 'builds a startTime range from -Last' {
            $null = Get-DMAlarmHistory -WebSession $script:session -Last (New-TimeSpan -Hours 1)

            $historyResource = $script:resources | Where-Object { $_ -like 'alarm/historyalarm*' } | Select-Object -First 1
            $historyResource | Should -Match 'startTime:\[\d+,\d+\]'
        }

        It 'maps sequence-range parameters to startSeq/endSeq' {
            $null = Get-DMAlarmHistory -WebSession $script:session -StartSequence 1000 -EndSequence 2000

            $historyResource = $script:resources | Where-Object { $_ -like 'alarm/historyalarm*' } | Select-Object -First 1
            $historyResource | Should -Match 'startSeq::1000'
            $historyResource | Should -Match 'endSeq::2000'
        }

        It 'maps -Sequence to sequence::N' {
            $null = Get-DMAlarmHistory -WebSession $script:session -Sequence 42

            $historyResource = $script:resources | Where-Object { $_ -like 'alarm/historyalarm*' } | Select-Object -First 1
            $historyResource | Should -Match 'sequence::42'
        }

        It 'rejects -Last combined with -StartTime' {
            { Get-DMAlarmHistory -WebSession $script:session -Last (New-TimeSpan -Hours 1) -StartTime (Get-Date) } |
                Should -Throw '*cannot be combined*'
        }
    }
}
