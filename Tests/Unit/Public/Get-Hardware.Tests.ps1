BeforeDiscovery {
    $script:getHardwareModule = New-Module -Name GetHardwareTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Private" -Filter 'class-*.ps1' |
            Where-Object Name -notin 'class-OceanStorMappingView.ps1', 'class-OceanstorSession.ps1' |
            ForEach-Object { . $_.FullName }

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Public" -Filter 'Get-*.ps1' |
            ForEach-Object { . $_.FullName }

        Export-ModuleMember -Function 'Get-*'
    }

    Import-Module $script:getHardwareModule -Force
}

AfterAll {
    Remove-Module -Name GetHardwareTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope GetHardwareTestModule {
Describe 'Public getter functions' {
    BeforeAll {
        $script:eLabel = @(
            'BoardType=board-01'
            'BarCode=serial-01'
            'Item=part-01'
            'Description=component'
            'Manufactured=2026-01-01'
            'VendorName=Huawei'
        ) -join "`n"
    }
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }
    }
    Describe 'Hardware getter functions' {
        It 'gets alarms using the requested alarm state' {
            Mock Invoke-DeviceManager {
                $script:resource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ name = 'warning'; alarmStatus = 2; level = 2; type = 1; eventType = 1; clearTime = 0; recoverTime = 0; startTime = 0 }) }
            }

            $result = Get-DMAlarm -WebSession $script:session -AlarmStatus Cleared

            $result[0].Name | Should -Be 'warning'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Name', 'Level', 'Alarm Status', 'Location', 'Start time')
            $result[0].'Event Type' | Should -Be 'alarm'
            $result[0].Session | Should -Be $script:session
            $script:resource | Should -BeLike 'alarm/historyalarm?filter=alarmStatus::2*'
        }

        It 'filters alarms by an explicit start and end time as a bracketed range' {
            Mock Invoke-DeviceManager {
                $script:resource = $Resource
                [pscustomobject]@{ data = @() }
            }

            $start = [datetime]::new(2026, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
            $end = [datetime]::new(2026, 1, 2, 0, 0, 0, [DateTimeKind]::Utc)
            $startEpoch = [System.DateTimeOffset]::new($start).ToUnixTimeSeconds()
            $endEpoch = [System.DateTimeOffset]::new($end).ToUnixTimeSeconds()

            $null = Get-DMAlarm -WebSession $script:session -StartTime $start -EndTime $end

            $script:resource | Should -Match ([regex]::Escape("alarm/historyalarm?filter=alarmStatus::1 and startTime:[$startEpoch,$endEpoch]"))
        }

        It 'filters alarms using a Last timespan relative to now' {
            Mock Invoke-DeviceManager {
                $script:resource = $Resource
                [pscustomobject]@{ data = @() }
            }

            $null = Get-DMAlarm -WebSession $script:session -Last (New-TimeSpan -Hours 24)

            $script:resource | Should -Match 'alarm/historyalarm\?filter=alarmStatus::1 and startTime:\[\d+,\d+\]'
        }

        It 'throws when -Last is combined with -StartTime or -EndTime' {
            { Get-DMAlarm -WebSession $script:session -Last (New-TimeSpan -Hours 1) -StartTime (Get-Date) } | Should -Throw
        }

        It 'gets battery backup units' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'bbu-01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 210; VOLTAGE = 120; REMAINLIFEDAYS = 30 }) }
            }

            $result = Get-DMbbu -WebSession $script:session

            $result[0].Id | Should -Be 'bbu-01'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'PSU Location', 'Health Status', 'Running Status', 'Remaining Life')
            $result[0].'Part Number' | Should -Be 'part-01'
        }

        It 'gets controllers' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'ctrl-01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 207; MEMORYSIZE = 1GB }) }
            }

            $result = (Get-DMController -WebSession $script:session)[0]

            $result.Id | Should -Be 'ctrl-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Running Status', 'Is Master')
            $result.'Memory Size' | Should -Be 1
        }

        It 'gets enclosures' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'enc-01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 206; MODEL = 17 }) }
            }

            $result = (Get-DMEnclosure -WebSession $script:session)[0]

            $result.Id | Should -Be 'enc-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Model')
            $result.'Part Number' | Should -Be 'part-01'
        }

        It 'gets interface modules' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'module-01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 209; MODEL = 2307 }) }
            }

            $result = (Get-DMInterfaceModule -WebSession $script:session)[0]

            $result.Id | Should -Be 'module-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Model')
            $result.'Part Number' | Should -Be 'part-01'
        }
    }
}
}
