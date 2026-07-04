BeforeDiscovery {
    $script:removeSnapshotModule = New-Module -Name RemoveDMLunSnapshotTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMLunSnapshot {
            param([pscustomobject]$WebSession, [string]$Name, [string]$Id)
        }

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunSnapShot.ps1"

        Export-ModuleMember -Function Remove-DMLunSnapShot
    }

    Import-Module $script:removeSnapshotModule -Force
}

AfterAll {
    Remove-Module -Name RemoveDMLunSnapshotTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope RemoveDMLunSnapshotTestModule {
Describe 'Remove-DMLunSnapShot' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMLunSnapshot {
            $items = @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' })
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }
        Mock Invoke-DeviceManager {
            $script:removeMethod = $Method
            $script:removeResource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
            }
        }
    }

    It 'removes an existing snapshot by its resolved ID' {
        $result = Remove-DMLunSnapShot -WebSession $script:session -SnapShotName 'before-patch' -Confirm:$false

        $result.Code | Should -Be 0
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
        $script:removeMethod | Should -Be 'DELETE'
        $script:removeResource | Should -Be 'snapshot/snap-01'
        Should -Invoke Get-DMLunSnapshot -Times 2 -Exactly -ParameterFilter { $Name -eq 'before-patch' -and -not $Id }
        Should -Invoke Get-DMLunSnapshot -Times 0 -Exactly -ParameterFilter { -not $Name -and -not $Id }
    }

    It 'does not call the API when WhatIf is specified' {
        $null = Remove-DMLunSnapShot -WebSession $script:session -SnapShotName 'before-patch' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a snapshot name that does not exist' {
        { Remove-DMLunSnapShot -WebSession $script:session -SnapShotName 'missing' -Confirm:$false } |
            Should -Throw '*Invalid SnapShotName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a snapshot name that is not unique' {
        Mock Get-DMLunSnapshot {
            $items = @(
                [pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' }
                [pscustomobject]@{ Id = 'snap-02'; Name = 'before-patch' }
            )
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }

        { Remove-DMLunSnapShot -WebSession $script:session -SnapShotName 'before-patch' -Confirm:$false } |
            Should -Throw '*SnapShotName is ambiguous*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'removes every snapshot piped in, not just the last one' {
        Mock Get-DMLunSnapshot {
            $items = @(
                [pscustomobject]@{ Id = 'snap-01'; Name = 'snap-a' }
                [pscustomobject]@{ Id = 'snap-02'; Name = 'snap-b' }
            )
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }

        $snapshots = @(
            [pscustomobject]@{ Name = 'snap-a' }
            [pscustomobject]@{ Name = 'snap-b' }
        )
        $null = $snapshots | Remove-DMLunSnapShot -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'snapshot/snap-01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'snapshot/snap-02' }
    }

    It 'removes an existing snapshot by Id' {
        Mock Get-DMLunSnapshot {
            param($WebSession, $Id)
            if ($Id -eq 'snap-01') { return @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' }) }
            @()
        }

        $result = Remove-DMLunSnapShot -WebSession $script:session -SnapShotId 'snap-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:removeResource | Should -Be 'snapshot/snap-01'
    }

    It 'rejects a snapshot Id that does not exist' {
        Mock Get-DMLunSnapshot {
            param($WebSession, $Id)
            @()
        }

        { Remove-DMLunSnapShot -WebSession $script:session -SnapShotId 'missing' -Confirm:$false } |
            Should -Throw '*Invalid SnapShotId*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects supplying both SnapShotName and SnapShotId' {
        { Remove-DMLunSnapShot -WebSession $script:session -SnapShotName 'before-patch' -SnapShotId 'snap-01' -Confirm:$false } |
            Should -Throw '*parameter set*'
    }
}
}
