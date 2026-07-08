BeforeDiscovery {
    $script:setAlarmMaskingModule = New-Module -Name SetAlarmMaskingTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMAlarmMasking.ps1"

        Export-ModuleMember -Function 'Set-DMAlarmMasking'
    }

    Import-Module $script:setAlarmMaskingModule -Force
}

AfterAll {
    Remove-Module -Name SetAlarmMaskingTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SetAlarmMaskingTestModule {
    Describe 'Set-DMAlarmMasking' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001' }
            $script:lastMethod = $null
            $script:lastResource = $null
            $script:lastBody = $null

            Mock Invoke-DeviceManager {
                $script:lastMethod = $Method
                $script:lastResource = $Resource
                $script:lastBody = $BodyData
                [pscustomobject]@{
                    data  = [pscustomobject]@{ TYPE = 16435 }
                    error = [pscustomobject]@{ code = 0; description = '0' }
                }
            }
        }

        It 'PUTs to ALARM_DEFINITION with enableClose = $true when -Enable is used' {
            $null = Set-DMAlarmMasking -WebSession $script:session -AlarmId '64425164820' -Enable -Confirm:$false

            $script:lastMethod | Should -Be 'PUT'
            $script:lastResource | Should -Be 'ALARM_DEFINITION'
            $script:lastBody.CMO_ALARM_ID | Should -Be '64425164820'
            $script:lastBody.enableClose | Should -BeTrue
        }

        It 'PUTs enableClose = $false when -Disable is used' {
            $null = Set-DMAlarmMasking -WebSession $script:session -AlarmId '64425164820' -Disable -Confirm:$false

            $script:lastBody.enableClose | Should -BeFalse
        }

        It 'returns the API error object on success' {
            $result = Set-DMAlarmMasking -WebSession $script:session -AlarmId '64425164820' -Enable -Confirm:$false

            $result.code | Should -Be 0
        }

        It 'does not call the API under -WhatIf' {
            Set-DMAlarmMasking -WebSession $script:session -AlarmId '64425164820' -Enable -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0
        }

        It 'requires one of -Enable / -Disable (ambiguous parameter set is rejected)' {
            { Set-DMAlarmMasking -WebSession $script:session -AlarmId '64425164820' -Enable -Disable -Confirm:$false } |
                Should -Throw
        }

        It 'rejects a non-numeric AlarmId' {
            { Set-DMAlarmMasking -WebSession $script:session -AlarmId 'not-a-number' -Enable -Confirm:$false } |
                Should -Throw
        }

        It 'binds AlarmId and WebSession from the pipeline (property name)' {
            $piped = [pscustomobject]@{ 'Alarm Id' = '99999'; WebSession = $script:session }
            $null = $piped | Set-DMAlarmMasking -Enable -Confirm:$false

            $script:lastBody.CMO_ALARM_ID | Should -Be '99999'
        }

        It 'surfaces a non-zero API error as a non-terminating error' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    data  = $null
                    error = [pscustomobject]@{ code = 1077949061; description = 'error' }
                }
            }

            Set-DMAlarmMasking -WebSession $script:session -AlarmId '64425164820' -Enable -Confirm:$false -Errorvariable maskErr -ErrorAction SilentlyContinue
            $maskErr.Count | Should -BeGreaterThan 0
        }
    }
}
