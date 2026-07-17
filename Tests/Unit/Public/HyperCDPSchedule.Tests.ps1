BeforeDiscovery {
    $script:hyperCdpModule = New-Module -Name HyperCDPScheduleTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        function Invoke-DMPagedRequest {
            param(
                [pscustomobject]$WebSession,
                [string]$Resource
            )
        }

        function Get-DMlun {
            param([pscustomobject]$WebSession, [string]$Name, [string]$Id)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\ConvertTo-DMHyperCDPSchedulePayload.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Resolve-DMHyperCDPLun.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Resolve-DMHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Enable-DMHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Disable-DMHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMLunToHyperCDPSchedule.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunFromHyperCDPSchedule.ps1"

        Export-ModuleMember -Function '*-DMHyperCDPSchedule', 'Add-DMLunToHyperCDPSchedule', 'Remove-DMLunFromHyperCDPSchedule'
    }

    Import-Module $script:hyperCdpModule -Force
}

AfterAll {
    Remove-Module -Name HyperCDPScheduleTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope HyperCDPScheduleTestModule {
Describe 'HyperCDP schedule commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:requests = [System.Collections.Generic.List[object]]::new()
        $script:scheduleData = [pscustomobject]@{
            ID = '7'
            NAME = 'sched01'
            DESCRIPTION = 'validation'
            SCHEDULETYPE = '1'
            OBJECTTYPE = '0'
            ENABLESCHEDULE = $false
            RUNNINGSTATUS = '31'
            HEALTHSTATUS = '1'
            LASTEXECUTIONRESULT = '0'
            LASTEXECUTIONTIME = '-1'
            FREQUENCYVALUE = '3600'
            FREQUENCYNUM = '2'
            DAYHOURS = '[]'
            DAYMINUTE = '-1'
            DAILYSNAPSHOTNUM = '-1'
            WEEKLYDAYS = '[]'
            WEEKLYSNAPSHOTNUM = '-1'
            MONTHDAYS = '[]'
            MONTHSNAPSHOTNUM = '-1'
            lunNum = '0'
            fsNum = '0'
            protectionGroupNum = '0'
            SECURESNAPENABLED = 'false'
            TYPE = 57527
        }
        Mock Invoke-DMPagedRequest {
            $script:pagedResource = $Resource
            @($script:scheduleData)
        }
        Mock Invoke-DeviceManager {
            $script:requests.Add([pscustomobject]@{ Method = $Method; Resource = $Resource; Body = $BodyData })
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0; description = '0' }
                data = $script:scheduleData
            }
        }
        Mock Get-DMlun {
            $items = @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'lun-b' }
            )
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }
    }

    It 'creates a non-secure fixed-period block HyperCDP schedule' {
        $result = New-DMHyperCDPSchedule -WebSession $script:session -Name 'sched01' `
            -Description 'validation' -FrequencyValueSeconds 3600 -FrequencySnapshotCount 2

        $result.GetType().Name | Should -Be 'OceanstorHyperCDPSchedule'
        $result.Id | Should -Be '7'
        $result.'Schedule Type' | Should -Be 'HyperCDP'
        $script:requests[0].Method | Should -Be 'POST'
        $script:requests[0].Resource | Should -Be 'snapshot_schedule'
        $script:requests[0].Body.SCHEDULETYPE | Should -Be 1
        $script:requests[0].Body.OBJECTTYPE | Should -Be '0'
        $script:requests[0].Body.FREQUENCYVALUE | Should -Be 3600
        $script:requests[0].Body.FREQUENCYNUM | Should -Be 2
        $script:requests[0].Body.ContainsKey('SECURESNAPENABLED') | Should -BeFalse
    }

    It 'rejects incomplete non-secure policy groups' {
        { New-DMHyperCDPSchedule -WebSession $script:session -Name 'sched01' -FrequencyValueSeconds 3600 } |
            Should -Throw '*Fixed-period policy parameters must be supplied together*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'queries schedules with HyperCDP schedule type filtering' {
        $result = Get-DMHyperCDPSchedule -WebSession $script:session -Name 'sched01'

        $result.Count | Should -Be 1
        $script:pagedResource | Should -Be 'snapshot_schedule?SCHEDULETYPE=1&filter=NAME::sched01'
    }

    It 'modifies a schedule by name' {
        $result = Set-DMHyperCDPSchedule -WebSession $script:session -ScheduleName 'sched01' `
            -Description 'updated' -Confirm:$false

        $result.Code | Should -Be 0
        ($script:requests | Select-Object -Last 1).Method | Should -Be 'PUT'
        ($script:requests | Select-Object -Last 1).Resource | Should -Be 'snapshot_schedule/7'
        ($script:requests | Select-Object -Last 1).Body.DESCRIPTION | Should -Be 'updated'
        ($script:requests | Select-Object -Last 1).Body.SCHEDULETYPE | Should -Be 1
        # Regression guard for OceanStor API error 50331651: the modify interface (REST
        # reference 4.9.12.3.3) marks ID as a Mandatory body field; the schedule payload
        # omits it, so Set-DMHyperCDPSchedule must echo the resolved ID in the body.
        ($script:requests | Select-Object -Last 1).Body.ID | Should -Be '7'
    }

    It 'enables and disables a schedule' {
        $null = Enable-DMHyperCDPSchedule -WebSession $script:session -ScheduleId '7' -Confirm:$false
        $null = Disable-DMHyperCDPSchedule -WebSession $script:session -ScheduleId '7' -Confirm:$false

        $toggleRequests = @($script:requests | Where-Object { $_.Resource -eq 'snapshot_schedule/enable_snapshot_schedule?SCHEDULETYPE=1' })
        $toggleRequests.Count | Should -Be 2
        $toggleRequests[0].Body.ENABLESCHEDULE | Should -BeTrue
        $toggleRequests[1].Body.ENABLESCHEDULE | Should -BeFalse
    }

    It 'removes a schedule with schedule type query parameters' {
        $result = Remove-DMHyperCDPSchedule -WebSession $script:session -ScheduleId '7' -Confirm:$false

        $result.Code | Should -Be 0
        ($script:requests | Select-Object -Last 1).Method | Should -Be 'DELETE'
        ($script:requests | Select-Object -Last 1).Resource | Should -Be 'snapshot_schedule/7?SCHEDULETYPE=1'
    }

    It 'adds a piped LUN to a HyperCDP schedule' {
        $lun = [pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a' }

        $result = $lun | Add-DMLunToHyperCDPSchedule -WebSession $script:session -ScheduleId '7' -Confirm:$false

        $result.Code | Should -Be 0
        ($script:requests | Select-Object -Last 1).Method | Should -Be 'POST'
        ($script:requests | Select-Object -Last 1).Resource | Should -Be 'snapshot_schedule/create_associate'
        ($script:requests | Select-Object -Last 1).Body.ID | Should -Be '7'
        ($script:requests | Select-Object -Last 1).Body.ASSOCIATEOBJTYPE | Should -Be 11
        ($script:requests | Select-Object -Last 1).Body.ASSOCIATEOBJID | Should -Be 'lun-01'
        ($script:requests | Select-Object -Last 1).Body.SCHEDULETYPE | Should -Be 1
    }

    It 'removes every piped LUN from a HyperCDP schedule' {
        $luns = @(
            [pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a' }
            [pscustomobject]@{ Id = 'lun-02'; Name = 'lun-b' }
        )

        $null = $luns | Remove-DMLunFromHyperCDPSchedule -WebSession $script:session -ScheduleId '7' -Confirm:$false

        ($script:requests | Where-Object { $_.Resource -like 'snapshot_schedule/remove_associate*ASSOCIATEOBJID=lun-01*' }).Count | Should -Be 1
        ($script:requests | Where-Object { $_.Resource -like 'snapshot_schedule/remove_associate*ASSOCIATEOBJID=lun-02*' }).Count | Should -Be 1
    }
}
}
