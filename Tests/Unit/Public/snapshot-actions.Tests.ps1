BeforeDiscovery {
    $script:snapshotActionsModule = New-Module -Name SnapshotActionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMLunSnapshot {
            param([pscustomobject]$WebSession, [string]$Name, [string]$Id)
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
            $items = @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' })
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
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
        Should -Invoke Get-DMLunSnapshot -Times 2 -Exactly -ParameterFilter { $Name -eq 'before-patch' -and -not $Id }
        Should -Invoke Get-DMLunSnapshot -Times 0 -Exactly -ParameterFilter { -not $Name -and -not $Id }
    }

    It 'reactivates an existing snapshot' {
        $result = Restart-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -Confirm:$false

        $result.Code | Should -Be 0
        $script:actionMethod | Should -Be 'PUT'
        $script:actionResource | Should -Be 'snapshot/reactive'
        $script:actionBody.ID | Should -Be 'snap-01'
        Should -Invoke Get-DMLunSnapshot -Times 2 -Exactly -ParameterFilter { $Name -eq 'before-patch' -and -not $Id }
        Should -Invoke Get-DMLunSnapshot -Times 0 -Exactly -ParameterFilter { -not $Name -and -not $Id }
    }

    It 'expands an existing snapshot using sector capacity' {
        $result = Resize-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -UserCapacity 10485760 -Confirm:$false

        $result.Code | Should -Be 0
        $script:actionMethod | Should -Be 'PUT'
        $script:actionResource | Should -Be 'snapshot/expand'
        $script:actionBody.ID | Should -Be 'snap-01'
        $script:actionBody.USERCAPACITY | Should -Be 10485760
        Should -Invoke Get-DMLunSnapshot -Times 2 -Exactly -ParameterFilter { $Name -eq 'before-patch' -and -not $Id }
        Should -Invoke Get-DMLunSnapshot -Times 0 -Exactly -ParameterFilter { -not $Name -and -not $Id }
    }

    It 'rolls back an existing snapshot using the selected speed' {
        $result = Restore-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -RollbackSpeed High -Confirm:$false

        $result.Code | Should -Be 0
        $script:actionMethod | Should -Be 'PUT'
        $script:actionResource | Should -Be 'snapshot/rollback'
        $script:actionBody.ID | Should -Be 'snap-01'
        $script:actionBody.ROLLBACKSPEED | Should -Be 3
        Should -Invoke Get-DMLunSnapshot -Times 2 -Exactly -ParameterFilter { $Name -eq 'before-patch' -and -not $Id }
        Should -Invoke Get-DMLunSnapshot -Times 0 -Exactly -ParameterFilter { -not $Name -and -not $Id }
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
            $items = @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch'; 'User Capacity' = [uint64]10485760 })
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }

        $result = Resize-DMLunSnapshot -WebSession $script:session -SnapShotName 'before-patch' -UserCapacity 10485760 -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable resizeErrors

        $result | Should -BeNullOrEmpty
        ($resizeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*greater than the current snapshot capacity*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> resolves an existing snapshot by Id' -TestCases @(
        @{ Command = 'Enable-DMLunSnapshot'; Parameters = @{}; ExpectedResource = 'snapshot/activate' }
        @{ Command = 'Restart-DMLunSnapshot'; Parameters = @{}; ExpectedResource = 'snapshot/reactive' }
        @{ Command = 'Resize-DMLunSnapshot'; Parameters = @{ UserCapacity = [uint64]10485760 }; ExpectedResource = 'snapshot/expand' }
        @{ Command = 'Restore-DMLunSnapshot'; Parameters = @{}; ExpectedResource = 'snapshot/rollback' }
    ) {
        param($Command, $Parameters, $ExpectedResource)
        Mock Get-DMLunSnapshot {
            param($WebSession, $Id)
            if ($Id -eq 'snap-01') { return @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' }) }
            @()
        }

        $result = & $Command -WebSession $script:session -SnapShotId 'snap-01' -Confirm:$false @Parameters

        $result.Code | Should -Be 0
        $script:actionResource | Should -Be $ExpectedResource
    }

    It '<Command> rejects a snapshot Id that does not exist' -TestCases @(
        @{ Command = 'Enable-DMLunSnapshot'; Parameters = @{} }
        @{ Command = 'Restart-DMLunSnapshot'; Parameters = @{} }
        @{ Command = 'Resize-DMLunSnapshot'; Parameters = @{ UserCapacity = [uint64]10485760 } }
        @{ Command = 'Restore-DMLunSnapshot'; Parameters = @{} }
    ) {
        param($Command, $Parameters)
        Mock Get-DMLunSnapshot {
            param($WebSession, $Id)
            @()
        }

        { & $Command -WebSession $script:session -SnapShotId 'missing' -Confirm:$false @Parameters } |
            Should -Throw '*Invalid SnapShotId*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> rejects supplying both SnapShotName and SnapShotId' -TestCases @(
        @{ Command = 'Enable-DMLunSnapshot'; Parameters = @{} }
        @{ Command = 'Restart-DMLunSnapshot'; Parameters = @{} }
        @{ Command = 'Resize-DMLunSnapshot'; Parameters = @{ UserCapacity = [uint64]10485760 } }
        @{ Command = 'Restore-DMLunSnapshot'; Parameters = @{} }
    ) {
        param($Command, $Parameters)

        { & $Command -WebSession $script:session -SnapShotName 'before-patch' -SnapShotId 'snap-01' -Confirm:$false @Parameters } |
            Should -Throw '*parameter set*'
    }

    It '<Command> accepts a snapshot from the pipeline by property Id' -TestCases @(
        @{ Command = 'Enable-DMLunSnapshot'; Parameters = @{}; ExpectedResource = 'snapshot/activate' }
        @{ Command = 'Restart-DMLunSnapshot'; Parameters = @{}; ExpectedResource = 'snapshot/reactive' }
        @{ Command = 'Resize-DMLunSnapshot'; Parameters = @{ UserCapacity = [uint64]10485760 }; ExpectedResource = 'snapshot/expand' }
        @{ Command = 'Restore-DMLunSnapshot'; Parameters = @{}; ExpectedResource = 'snapshot/rollback' }
    ) {
        param($Command, $Parameters, $ExpectedResource)
        Mock Get-DMLunSnapshot {
            param($WebSession, $Id)
            if ($Id -eq 'snap-01') { return @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' }) }
            @()
        }

        $piped = [pscustomobject]@{ Id = 'snap-01' }
        $result = $piped | & $Command -WebSession $script:session -Confirm:$false @Parameters

        $result.Code | Should -Be 0
        $script:actionResource | Should -Be $ExpectedResource
    }
}
}
