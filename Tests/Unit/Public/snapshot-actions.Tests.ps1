BeforeDiscovery {
    $script:snapshotActionsModule = New-Module -Name SnapshotActionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMLunSnapshot {
            param([pscustomobject]$WebSession)
        }

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Enable-DMLunSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Restart-DMLunSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Resize-DMLunSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Restore-DMLunSnapshot.ps1"

        Export-ModuleMember -Function '*-DMLunSnapshot'
    }

    Import-Module $script:snapshotActionsModule -Force
}

AfterAll {
    Remove-Module -Name SnapshotActionsTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SnapshotActionsTestModule {
Describe 'Snapshot action functions' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMLunSnapshot {
            @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' })
        }
        Mock Invoke-DeviceManager {
            $script:actionMethod = $Method
            $script:actionResource = $Resource
            $script:actionBody = $BodyData
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
            }
        }
    }

    It 'activates an existing snapshot' {
        $result = Enable-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -Confirm:$false

        $result.Code | Should -Be 0
        $script:actionMethod | Should -Be 'POST'
        $script:actionResource | Should -Be 'snapshot/activate'
        $script:actionBody.SNAPSHOTLIST | Should -Be @('snap-01')
    }

    It 'reactivates an existing snapshot' {
        $result = Restart-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -Confirm:$false

        $result.Code | Should -Be 0
        $script:actionMethod | Should -Be 'PUT'
        $script:actionResource | Should -Be 'snapshot/reactive'
        $script:actionBody.ID | Should -Be 'snap-01'
    }

    It 'expands an existing snapshot using sector capacity' {
        $result = Resize-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -UserCapacity 10485760 -Confirm:$false

        $result.Code | Should -Be 0
        $script:actionMethod | Should -Be 'PUT'
        $script:actionResource | Should -Be 'snapshot/expand'
        $script:actionBody.ID | Should -Be 'snap-01'
        $script:actionBody.USERCAPACITY | Should -Be 10485760
    }

    It 'rolls back an existing snapshot using the selected speed' {
        $result = Restore-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -RollbackSpeed High -Confirm:$false

        $result.Code | Should -Be 0
        $script:actionMethod | Should -Be 'PUT'
        $script:actionResource | Should -Be 'snapshot/rollback'
        $script:actionBody.ID | Should -Be 'snap-01'
        $script:actionBody.ROLLBACKSPEED | Should -Be 3
    }

    It '<Command> does not call the API when WhatIf is specified' -TestCases @(
        @{ Command = 'Enable-DMLunSnapshot'; Parameters = @{} }
        @{ Command = 'Restart-DMLunSnapshot'; Parameters = @{} }
        @{ Command = 'Resize-DMLunSnapshot'; Parameters = @{ UserCapacity = [uint64]10485760 } }
        @{ Command = 'Restore-DMLunSnapshot'; Parameters = @{} }
    ) {
        param($Command, $Parameters)

        $null = & $Command -WebSession $script:session -SnapShotName 'before-patch' -WhatIf @Parameters

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> rejects a snapshot name that does not exist' -TestCases @(
        @{ Command = 'Enable-DMLunSnapshot'; Parameters = @{} }
        @{ Command = 'Restart-DMLunSnapshot'; Parameters = @{} }
        @{ Command = 'Resize-DMLunSnapshot'; Parameters = @{ UserCapacity = [uint64]10485760 } }
        @{ Command = 'Restore-DMLunSnapshot'; Parameters = @{} }
    ) {
        param($Command, $Parameters)

        { & $Command -WebSession $script:session -SnapShotName 'missing' -Confirm:$false @Parameters } |
            Should -Throw '*Invalid SnapShotName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a zero snapshot expansion capacity' {
        { Resize-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -UserCapacity 0 -Confirm:$false } |
            Should -Throw

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects an expansion capacity that is not greater than the existing snapshot capacity' {
        Mock Get-DMLunSnapshot {
            @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch'; 'User Capacity' = [uint64]10485760 })
        }

        { Resize-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -UserCapacity 10485760 -Confirm:$false } |
            Should -Throw '*greater than the current snapshot capacity*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
