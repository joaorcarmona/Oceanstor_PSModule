BeforeDiscovery {
    $script:alarmMaskingModule = New-Module -Name AlarmMaskingTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorAlarmMasking.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMAlarmType.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMAlarmMasking.ps1"

        Export-ModuleMember -Function 'Get-DMAlarmMasking', 'Get-DMAlarmType'
    }

    Import-Module $script:alarmMaskingModule -Force
}

AfterAll {
    Remove-Module -Name AlarmMaskingTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope AlarmMaskingTestModule {
    Describe 'Get-DMAlarmMasking' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001' }
            $script:resources = New-Object System.Collections.Generic.List[string]

            # One masking sample; enableClose/isExistAlarm are string booleans and
            # level 5 exercises the severity mapping.
            $script:sampleMasking = [pscustomobject]@{
                CMO_ALARM_ID       = '14155777'
                CMO_ALARM_LEVEL    = '5'
                CMO_ALARM_NAME     = 'Storage Pool Remaining Capacity Is Insufficient'
                CMO_ALARM_OBJ_TYPE = '216'
                ID                 = '0'
                TYPE               = 16435
                enableClose        = 'false'
                isExistAlarm       = 'true'
            }

            # Records every composed Resource and answers both the alarm-type catalog
            # lookup and the masking query.
            Mock Invoke-DeviceManager {
                $script:resources.Add($Resource)
                if ($Resource -like 'ALARM_DEFINITION_OBJ*') {
                    [pscustomobject]@{
                        error = [pscustomobject]@{ Code = 0 }
                        data  = @(
                            [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'disk'; CMO_ALARM_OBJ_TYPE = '10'; ID = '1' }
                            [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'storage pool'; CMO_ALARM_OBJ_TYPE = '216'; ID = '2' }
                        )
                    }
                }
                else {
                    [pscustomobject]@{
                        error = [pscustomobject]@{ Code = 0 }
                        data  = @($script:sampleMasking)
                    }
                }
            }
        }

        It 'queries the documented ALARM_DEFINITION resource in English and shapes the output' {
            $result = @(Get-DMAlarmMasking -WebSession $script:session)

            $result.Count | Should -Be 1
            $result[0].GetType().Name | Should -Be 'OceanStorAlarmMasking'
            $result[0].'Alarm Id' | Should -Be '14155777'
            $result[0].Name | Should -Be 'Storage Pool Remaining Capacity Is Insufficient'
            $result[0].Level | Should -Be 'major'
            # Numeric object type 216 is translated to its catalog name; the raw
            # numeric is retained on Alarm Object Type Id.
            $result[0].'Alarm Object Type' | Should -Be 'storage pool'
            $result[0].'Alarm Object Type Id' | Should -Be '216'
            $result[0].Masked | Should -BeFalse
            $result[0].'Uncleared Alarm Exists' | Should -BeTrue

            $maskingResource = $script:resources | Where-Object { ($_ -like 'ALARM_DEFINITION*' -and $_ -notlike 'ALARM_DEFINITION_OBJ*') } | Select-Object -First 1
            $maskingResource | Should -BeLike '*language=1*'
            $maskingResource | Should -Not -BeLike '*filter=*'
        }

        It 'maps -Level Critical to CMO_ALARM_LEVEL::6' {
            $null = Get-DMAlarmMasking -WebSession $script:session -Level Critical

            $maskingResource = $script:resources | Where-Object { ($_ -like 'ALARM_DEFINITION*' -and $_ -notlike 'ALARM_DEFINITION_OBJ*') } | Select-Object -First 1
            $maskingResource | Should -Match 'CMO_ALARM_LEVEL::6'
        }

        It 'maps -Masked $true to enableClose::true and -Masked $false to enableClose::false' {
            $null = Get-DMAlarmMasking -WebSession $script:session -Masked $true
            ($script:resources | Where-Object { ($_ -like 'ALARM_DEFINITION*' -and $_ -notlike 'ALARM_DEFINITION_OBJ*') } | Select-Object -First 1) |
                Should -Match 'enableClose::true'

            $script:resources.Clear()
            $null = Get-DMAlarmMasking -WebSession $script:session -Masked $false
            ($script:resources | Where-Object { ($_ -like 'ALARM_DEFINITION*' -and $_ -notlike 'ALARM_DEFINITION_OBJ*') } | Select-Object -First 1) |
                Should -Match 'enableClose::false'
        }

        It 'resolves -AlarmObjectType name to its numeric value via the catalog and AND-joins clauses' {
            $null = Get-DMAlarmMasking -WebSession $script:session -Level Major -AlarmObjectType 'storage pool'

            ($script:resources | Where-Object { $_ -like 'ALARM_DEFINITION_OBJ*' }).Count | Should -BeGreaterThan 0
            $maskingResource = $script:resources | Where-Object { ($_ -like 'ALARM_DEFINITION*' -and $_ -notlike 'ALARM_DEFINITION_OBJ*') } | Select-Object -First 1
            $maskingResource | Should -Match 'CMO_ALARM_LEVEL::5 and CMO_ALARM_OBJ_TYPE::216'
        }

        It 'falls back to the numeric object type when it is absent from the catalog' {
            $script:sampleMasking.CMO_ALARM_OBJ_TYPE = '999'

            $result = @(Get-DMAlarmMasking -WebSession $script:session)

            $result[0].'Alarm Object Type' | Should -Be '999'
            $result[0].'Alarm Object Type Id' | Should -Be '999'
        }

        It 'throws a clear error for an unknown -AlarmObjectType name' {
            { Get-DMAlarmMasking -WebSession $script:session -AlarmObjectType nope } |
                Should -Throw "*Unknown alarm object type 'nope'*"
        }

        It 'tolerates an empty catalog' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
            }

            $result = @(Get-DMAlarmMasking -WebSession $script:session)
            $result.Count | Should -Be 0
        }
    }
}
