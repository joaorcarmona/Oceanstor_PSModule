BeforeDiscovery {
    $script:newSnapshotModule = New-Module -Name NewDMLunSnapshotTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlun {
            param([pscustomobject]$WebSession, [string]$Id)
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMLunSnapshot.ps1"

        Export-ModuleMember -Function New-DMLunSnapshot
    }

    Import-Module $script:newSnapshotModule -Force
}

AfterAll {
    Remove-Module -Name NewDMLunSnapshotTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewDMLunSnapshotTestModule {
Describe 'New-DMLunSnapshot' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlun {
            @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' })
        }
        Mock Invoke-DeviceManager {
            $script:snapshotRequest = $BodyData
            $script:snapshotMethod = $Method
            $script:snapshotResource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{
                    ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-01'
                    SOURCELUNNAME = 'data-lun'; HEALTHSTATUS = 1; RUNNINGSTATUS = 43
                    USERCAPACITY = 2097152; CONSUMEDCAPACITY = 1024; IOPRIORITY = 2
                    isReadOnly = $true; WWN = 'snapshot-wwn'
                }
            }
        }
    }

    It 'creates a snapshot for an existing LUN' {
        $result = New-DMLunSnapshot -WebSession $script:session -SnapshotName 'before-patch' -SourceLunName 'data-lun' -Description 'Patch checkpoint' -ReadOnly

        $result.GetType().Name | Should -Be 'OceanstorLunSnapshot'
        $result.Id | Should -Be 'snap-01'
        $result.'Source Lun Id' | Should -Be 'lun-01'
        $result.'Running Status' | Should -Be '43'
        $result.'Read Only' | Should -BeTrue
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
        $script:snapshotMethod | Should -Be 'POST'
        $script:snapshotResource | Should -Be 'snapshot'
        $script:snapshotRequest.TYPE | Should -Be 27
        $script:snapshotRequest.PARENTTYPE | Should -Be 11
        $script:snapshotRequest.PARENTID | Should -Be 'lun-01'
        $script:snapshotRequest.DESCRIPTION | Should -Be 'Patch checkpoint'
        $script:snapshotRequest.isReadOnly | Should -BeTrue
    }

    It 'generates a snapshot name when one is not supplied' {
        $null = New-DMLunSnapshot -WebSession $script:session -SourceLunName 'data-lun'

        $script:snapshotRequest.NAME | Should -Match '^snap_data-lun-\d{14}$'
        $script:snapshotRequest.PARENTID | Should -Be 'lun-01'
    }

    It 'rejects a source LUN name that does not exist' {
        { New-DMLunSnapshot -WebSession $script:session -SnapshotName 'before-patch' -SourceLunName 'missing' } |
            Should -Throw '*Invalid SourceLunName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a source LUN name that is not unique' {
        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'data-lun' }
            )
        }

        { New-DMLunSnapshot -WebSession $script:session -SnapshotName 'before-patch' -SourceLunName 'data-lun' } |
            Should -Throw '*SourceLunName is ambiguous*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'creates a snapshot for an existing LUN identified by Id' {
        Mock Get-DMlun {
            param($WebSession, $Id)
            if ($Id -eq 'lun-01') { return @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' }) }
            @()
        }

        $result = New-DMLunSnapshot -WebSession $script:session -SnapshotName 'before-patch' -SourceLunId 'lun-01'

        $result.Id | Should -Be 'snap-01'
        $script:snapshotRequest.PARENTID | Should -Be 'lun-01'
    }

    It 'rejects a source LUN Id that does not exist' {
        Mock Get-DMlun {
            param($WebSession, $Id)
            @()
        }

        { New-DMLunSnapshot -WebSession $script:session -SnapshotName 'before-patch' -SourceLunId 'missing' } |
            Should -Throw '*Invalid SourceLunId*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects supplying both SourceLunName and SourceLunId' {
        { New-DMLunSnapshot -WebSession $script:session -SourceLunName 'data-lun' -SourceLunId 'lun-01' } |
            Should -Throw '*parameter set*'
    }

    It 'accepts a source LUN from the pipeline by property Name' {
        $lun = [pscustomobject]@{ Name = 'data-lun' }

        $result = $lun | New-DMLunSnapshot -WebSession $script:session

        $result.Id | Should -Be 'snap-01'
        $script:snapshotRequest.PARENTID | Should -Be 'lun-01'
    }

    It 'creates a snapshot for every source LUN piped in, not just the last one' {
        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'other-lun' }
            )
        }

        $luns = @(
            [pscustomobject]@{ Name = 'data-lun' }
            [pscustomobject]@{ Name = 'other-lun' }
        )
        $null = $luns | New-DMLunSnapshot -WebSession $script:session

        Should -Invoke Invoke-DeviceManager -Times 2 -Exactly
    }
}
}
