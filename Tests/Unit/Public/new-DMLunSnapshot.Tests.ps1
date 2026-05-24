BeforeDiscovery {
    $script:newSnapshotModule = New-Module -Name NewDMLunSnapshotTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function get-DMluns {
            param([pscustomobject]$WebSession)
        }

        function invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\new-DMLunSnapshot.ps1"

        Export-ModuleMember -Function new-DMLunSnapshot
    }

    Import-Module $script:newSnapshotModule -Force
}

AfterAll {
    Remove-Module -Name NewDMLunSnapshotTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewDMLunSnapshotTestModule {
Describe 'new-DMLunSnapshot' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock get-DMluns {
            @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' })
        }
        Mock invoke-DeviceManager {
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
        $result = new-DMLunSnapshot -WebSession $script:session -SnapshotName 'before-patch' -SourceLunName 'data-lun' -Description 'Patch checkpoint' -ReadOnly

        $result.GetType().Name | Should -Be 'OceanstorLunSnapshot'
        $result.Id | Should -Be 'snap-01'
        $result.'Source Lun Id' | Should -Be 'lun-01'
        $result.'Running Status' | Should -Be '43'
        $result.'Read Only' | Should -BeTrue
        Should -Invoke invoke-DeviceManager -Times 1 -Exactly
        $script:snapshotMethod | Should -Be 'POST'
        $script:snapshotResource | Should -Be 'snapshot'
        $script:snapshotRequest.TYPE | Should -Be 27
        $script:snapshotRequest.PARENTTYPE | Should -Be 11
        $script:snapshotRequest.PARENTID | Should -Be 'lun-01'
        $script:snapshotRequest.DESCRIPTION | Should -Be 'Patch checkpoint'
        $script:snapshotRequest.isReadOnly | Should -BeTrue
    }

    It 'generates a snapshot name when one is not supplied' {
        $null = new-DMLunSnapshot -WebSession $script:session -SourceLunName 'data-lun'

        $script:snapshotRequest.NAME | Should -Match '^snap-data-lun-\d{14}$'
        $script:snapshotRequest.PARENTID | Should -Be 'lun-01'
    }

    It 'rejects a source LUN name that does not exist' {
        { new-DMLunSnapshot -WebSession $script:session -SnapshotName 'before-patch' -SourceLunName 'missing' } |
            Should -Throw '*Invalid SourceLunName*'

        Should -Invoke invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a source LUN name that is not unique' {
        Mock get-DMluns {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'data-lun' }
            )
        }

        { new-DMLunSnapshot -WebSession $script:session -SnapshotName 'before-patch' -SourceLunName 'data-lun' } |
            Should -Throw '*SourceLunName is ambiguous*'

        Should -Invoke invoke-DeviceManager -Times 0 -Exactly
    }
}
}
