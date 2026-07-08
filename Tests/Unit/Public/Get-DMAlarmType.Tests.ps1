BeforeDiscovery {
    $script:alarmTypeModule = New-Module -Name AlarmTypeTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMAlarmType.ps1"

        Export-ModuleMember -Function 'Get-DMAlarmType'
    }

    Import-Module $script:alarmTypeModule -Force
}

AfterAll {
    Remove-Module -Name AlarmTypeTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope AlarmTypeTestModule {
    Describe 'Get-DMAlarmType' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001' }
            $script:resource = $null
        }

        It 'queries the documented ALARM_DEFINITION_OBJ catalog in English and shapes the output' {
            Mock Invoke-DeviceManager {
                $script:resource = $Resource
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @(
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'port'; CMO_ALARM_OBJ_TYPE = '6'; ID = '0'; TYPE = 16508 }
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'disk'; CMO_ALARM_OBJ_TYPE = '10'; ID = '1'; TYPE = 16508 }
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'LUN'; CMO_ALARM_OBJ_TYPE = '11'; ID = '2'; TYPE = 16508 }
                    )
                }
            }

            $result = @(Get-DMAlarmType -WebSession $script:session)

            $result.Count | Should -Be 3
            $script:resource | Should -BeLike 'ALARM_DEFINITION_OBJ?language=1*'
            $result[1].Name | Should -Be 'disk'
            $result[1].ObjectType | Should -Be '10'
            $result[1].Id | Should -Be '1'
        }

        It 'filters by -Name (case-insensitive, exact) client-side' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @(
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'port'; CMO_ALARM_OBJ_TYPE = '6'; ID = '0' }
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'disk'; CMO_ALARM_OBJ_TYPE = '10'; ID = '1' }
                    )
                }
            }

            $result = @(Get-DMAlarmType -WebSession $script:session -Name 'DISK')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'disk'
        }

        It 'tolerates an empty catalog' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
            }

            $result = @(Get-DMAlarmType -WebSession $script:session)

            $result.Count | Should -Be 0
        }
    }
}
