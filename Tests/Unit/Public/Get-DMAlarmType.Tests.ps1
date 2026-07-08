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
        }

        It 'serves the internal catalog without querying the array' {
            Mock Invoke-DeviceManager { }

            $result = @(Get-DMAlarmType -WebSession $script:session)

            # The full hardcoded catalog is returned.
            $result.Count | Should -Be 117
            Should -Invoke Invoke-DeviceManager -Times 0

            # Spot-check the well-known low object types are shaped correctly.
            ($result | Where-Object { $_.ObjectType -eq '6' }).Name  | Should -Be 'Port'
            ($result | Where-Object { $_.ObjectType -eq '10' }).Name | Should -Be 'Disk'
            ($result | Where-Object { $_.ObjectType -eq '11' }).Name | Should -Be 'LUN'
            ($result | Where-Object { $_.ObjectType -eq '6' }).Id    | Should -Be '0'
        }

        It 'filters by -Name (case-insensitive, exact) against the internal list without an array call' {
            Mock Invoke-DeviceManager { }

            $result = @(Get-DMAlarmType -WebSession $script:session -Name 'DISK')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'Disk'
            $result[0].ObjectType | Should -Be '10'
            Should -Invoke Invoke-DeviceManager -Times 0
        }

        It 'resolves a known -ObjectType from the internal list without an array call' {
            Mock Invoke-DeviceManager { }

            $result = @(Get-DMAlarmType -WebSession $script:session -ObjectType '60011')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'Distributed protocol'
            Should -Invoke Invoke-DeviceManager -Times 0
        }

        It 'falls back to the array only when -ObjectType is absent from the internal list' {
            $script:resource = $null
            Mock Invoke-DeviceManager {
                $script:resource = $Resource
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @(
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'Future type'; CMO_ALARM_OBJ_TYPE = '99999'; ID = '900' }
                    )
                }
            }

            $result = @(Get-DMAlarmType -WebSession $script:session -ObjectType '99999')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'Future type'
            $result[0].ObjectType | Should -Be '99999'
            Should -Invoke Invoke-DeviceManager -Times 1
            $script:resource | Should -BeLike 'ALARM_DEFINITION_OBJ?language=1*'
        }

        It 'returns nothing when a fallback -ObjectType is unknown to the array too' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
            }

            $result = @(Get-DMAlarmType -WebSession $script:session -ObjectType '99999')

            $result.Count | Should -Be 0
            Should -Invoke Invoke-DeviceManager -Times 1
        }

        It '-Database Storage bypasses the internal list and reads the live catalog' {
            $script:resource = $null
            Mock Invoke-DeviceManager {
                $script:resource = $Resource
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @(
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'port'; CMO_ALARM_OBJ_TYPE = '6'; ID = '0' }
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'disk'; CMO_ALARM_OBJ_TYPE = '10'; ID = '1' }
                    )
                }
            }

            $result = @(Get-DMAlarmType -WebSession $script:session -Database Storage)

            # Only the live rows are returned, not the 117-entry internal list.
            $result.Count | Should -Be 2
            $result[0].Name | Should -Be 'port'
            Should -Invoke Invoke-DeviceManager -Times 1
            $script:resource | Should -BeLike 'ALARM_DEFINITION_OBJ?language=1*'
        }

        It '-Database Storage applies -Name and -ObjectType filters client-side' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @(
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'port'; CMO_ALARM_OBJ_TYPE = '6'; ID = '0' }
                        [pscustomobject]@{ CMO_ALARM_OBJ_NAME = 'disk'; CMO_ALARM_OBJ_TYPE = '10'; ID = '1' }
                    )
                }
            }

            $byName = @(Get-DMAlarmType -WebSession $script:session -Database Storage -Name 'DISK')
            $byName.Count | Should -Be 1
            $byName[0].ObjectType | Should -Be '10'

            $byType = @(Get-DMAlarmType -WebSession $script:session -Database Storage -ObjectType '6')
            $byType.Count | Should -Be 1
            $byType[0].Name | Should -Be 'port'
        }

        It '-Database Internal (explicit) serves the internal list without an array call' {
            Mock Invoke-DeviceManager { }

            $result = @(Get-DMAlarmType -WebSession $script:session -Database Internal)

            $result.Count | Should -Be 117
            Should -Invoke Invoke-DeviceManager -Times 0
        }
    }
}
