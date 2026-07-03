BeforeDiscovery {
    $script:removeSnapshotModule = New-Module -Name RemoveDMLunSnapshotTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMLunSnapshot {
            param([pscustomobject]$WebSession)
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
            @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' })
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
    }

    It 'does not call the API when WhatIf is specified' {
        $null = Remove-DMLunSnapShot -WebSession $script:session -SnapShotName 'before-patch' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error for a snapshot name that does not exist' {
        $result = Remove-DMLunSnapShot -WebSession $script:session -SnapShotName 'missing' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid SnapShotName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error for a snapshot name that is not unique' {
        Mock Get-DMLunSnapshot {
            @(
                [pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' }
                [pscustomobject]@{ Id = 'snap-02'; Name = 'before-patch' }
            )
        }

        $result = Remove-DMLunSnapShot -WebSession $script:session -SnapShotName 'before-patch' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*SnapShotName is ambiguous*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'removes every snapshot piped in, not just the last one' {
        Mock Get-DMLunSnapshot {
            @(
                [pscustomobject]@{ Id = 'snap-01'; Name = 'snap-a' }
                [pscustomobject]@{ Id = 'snap-02'; Name = 'snap-b' }
            )
        }

        $snapshots = @(
            [pscustomobject]@{ Name = 'snap-a' }
            [pscustomobject]@{ Name = 'snap-b' }
        )
        $null = $snapshots | Remove-DMLunSnapShot -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'snapshot/snap-01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'snapshot/snap-02' }
    }
}
}
