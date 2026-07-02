BeforeDiscovery {
    $script:newSnapshotCopyModule = New-Module -Name NewDMLunSnapshotCopyTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMLunSnapshotCopy.ps1"

        Export-ModuleMember -Function New-DMLunSnapshotCopy
    }

    Import-Module $script:newSnapshotCopyModule -Force
}

AfterAll {
    Remove-Module -Name NewDMLunSnapshotCopyTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewDMLunSnapshotCopyTestModule {
Describe 'New-DMLunSnapshotCopy' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMLunSnapshot {
            @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' })
        }
        Mock Invoke-DeviceManager {
            $script:snapshotCopyRequest = $BodyData
            $script:snapshotCopyMethod = $Method
            $script:snapshotCopyResource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{
                    ID = 'snap-02'; NAME = $BodyData.NAME; SOURCELUNID = 'lun-01'
                    SOURCELUNNAME = 'data-lun'; HEALTHSTATUS = 1; RUNNINGSTATUS = 43
                    USERCAPACITY = 2097152; CONSUMEDCAPACITY = 0; IOPRIORITY = 1
                    isReadOnly = $false; WWN = 'copy-wwn'
                }
            }
        }
    }

    It 'creates a named snapshot copy from an existing snapshot' {
        $result = New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch' -SnapshotCopyName 'patch-copy' -Description 'Copy for testing'

        $result.GetType().Name | Should -Be 'OceanstorLunSnapshot'
        $result.Id | Should -Be 'snap-02'
        $result.Name | Should -Be 'patch-copy'
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
        $script:snapshotCopyMethod | Should -Be 'POST'
        $script:snapshotCopyResource | Should -Be 'snapshot/createcopy'
        $script:snapshotCopyRequest.ID | Should -Be 'snap-01'
        $script:snapshotCopyRequest.NAME | Should -Be 'patch-copy'
        $script:snapshotCopyRequest.DESCRIPTION | Should -Be 'Copy for testing'
    }

    It 'creates a default copy name from the original snapshot name' {
        $result = New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch'

        $result.Name | Should -Be 'copy_before-patch'
        $script:snapshotCopyRequest.NAME | Should -Be 'copy_before-patch'
        $script:snapshotCopyRequest.ID | Should -Be 'snap-01'
    }

    It 'rejects a source snapshot name that does not exist' {
        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'missing' } |
            Should -Throw '*Invalid SourceSnapShotName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a source snapshot name that is not unique' {
        Mock Get-DMLunSnapshot {
            @(
                [pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' }
                [pscustomobject]@{ Id = 'snap-02'; Name = 'before-patch' }
            )
        }

        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch' } |
            Should -Throw '*SourceSnapShotName is ambiguous*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects copy names that contain unsupported characters' {
        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch' -SnapshotCopyName 'bad copy name' } |
            Should -Throw

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'requires an explicit copy name when the generated name exceeds the API limit' {
        $longName = 'a' * 252
        Mock Get-DMLunSnapshot {
            @([pscustomobject]@{ Id = 'snap-long'; Name = $longName })
        }

        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName $longName } |
            Should -Throw '*generated SnapshotCopyName exceeds*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
