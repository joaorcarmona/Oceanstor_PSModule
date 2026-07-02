BeforeDiscovery {
    $script:fileSystemSnapshotModule = New-Module -Name FileSystemSnapshotTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMFileSystem { param([pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorFileSystemSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMFileSystemSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMFileSystemSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMFileSystemSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Restore-DMFileSystemSnapshot.ps1"

        Export-ModuleMember -Function '*-DMFileSystemSnapshot', '*-DMFileSystemSnapshots'
    }

    Import-Module $script:fileSystemSnapshotModule -Force
}

AfterAll {
    Remove-Module -Name FileSystemSnapshotTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope FileSystemSnapshotTestModule {
Describe 'File-system snapshot commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = '5'; Name = 'documents' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{
                ID = '5@checkpoint'; NAME = 'checkpoint'; PARENTID = '5'; PARENTNAME = 'documents'
                HEALTHSTATUS = '1'; SNAPTYPE = '1'; TIMESTAMP = '1594990822'; vstoreId = '0'
            } }
        }
    }

    It 'creates a snapshot using the resolved file-system ID' {
        $result = New-DMFileSystemSnapshot -WebSession $script:session -SnapshotName 'checkpoint' -FileSystemName 'documents' -Description 'Before update' -SnapTag 'tag1'

        $result.GetType().Name | Should -Be 'OceanstorFileSystemSnapshot'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'fssnapshot'
        $script:request.PARENTTYPE | Should -Be 40
        $script:request.PARENTID | Should -Be '5'
        $script:request.snapType | Should -Be 1
        $script:request.description | Should -Be 'Before update'
        $script:request.snapTag | Should -Be 'tag1'
    }

    It 'generates a snapshot name when one is not supplied' {
        $null = New-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'documents'

        $script:request.NAME | Should -Match '^snap_documents-\d{14}$'
    }

    It 'rejects an invalid file-system name on create' {
        { New-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'missing' } |
            Should -Throw '*Invalid FileSystemName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'gets file-system snapshots under the resolved parent ID' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{
                ID = '5@checkpoint'; NAME = 'checkpoint'; PARENTID = '5'; PARENTNAME = 'documents'
                HEALTHSTATUS = '1'; SNAPTYPE = '1'; TIMESTAMP = '1594990822'; isSecuritySnap = 'false'
            }) }
        }

        $result = Get-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'documents'

        $result[0].GetType().Name | Should -Be 'OceanstorFileSystemSnapshot'
        $result[0].'Source File System Name' | Should -Be 'documents'
        $result[0].'Security Snapshot' | Should -BeFalse
        $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
            Should -Be @('Id', 'Name', 'Source File System Name', 'Health Status', 'Snapshot Type', 'Timestamp')
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'fssnapshot?filter=PARENTID:5'
    }

    It 'gets a named file-system snapshot directly by its composite ID' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{
                ID = '5@checkpoint'; NAME = 'checkpoint'; PARENTID = '5'; PARENTNAME = 'documents'
                HEALTHSTATUS = '1'; SNAPTYPE = '1'; TIMESTAMP = '1594990822'
            } }
        }

        $result = Get-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'documents' -SnapshotName 'checkpoint'

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'checkpoint'
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'fssnapshot/5@checkpoint'
    }

    It 'returns no file-system snapshots when the API contains no data property' {
        Mock Invoke-DeviceManager { [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } } }

        @(Get-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'documents') | Should -BeNullOrEmpty
    }

    It 'falls back to the legacy parent query when the filter lookup returns no data' {
        $script:requestedResources = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-DeviceManager {
            $script:requestedResources.Add($Resource)
            switch ($Resource) {
                'fssnapshot?filter=PARENTID:5' {
                    [pscustomobject]@{ data = @() }
                    break
                }
                'fssnapshot?PARENTID=5' {
                    [pscustomobject]@{ data = @(
                        [pscustomobject]@{ ID = '5@checkpoint'; NAME = 'checkpoint'; PARENTID = '5'; PARENTNAME = 'documents'; HEALTHSTATUS = '1'; SNAPTYPE = '1'; TIMESTAMP = '1594990822' }
                    ) }
                    break
                }
            }
        }

        $result = Get-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'documents'

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'checkpoint'
        $script:requestedResources[0] | Should -Be 'fssnapshot?filter=PARENTID:5'
        $script:requestedResources[1] | Should -Be 'fssnapshot?PARENTID=5'
    }

    It 'makes a single API call for lists regardless of how many snapshots exist' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = @(1..100 | ForEach-Object {
                [pscustomobject]@{ ID = "5@snap-$_"; NAME = "snap-$_"; PARENTID = '5'; PARENTNAME = 'documents'; HEALTHSTATUS = '1'; SNAPTYPE = '1'; TIMESTAMP = '1594990822' }
            }) }
        }

        $result = Get-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'documents'

        $result.Count | Should -Be 100
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'deletes a selected file-system snapshot by ID' {
        Mock Get-DMFileSystemSnapshot {
            @([OceanstorFileSystemSnapshot]::new([pscustomobject]@{ ID = '5@checkpoint'; NAME = 'checkpoint'; PARENTID = '5'; PARENTNAME = 'documents' }, $script:session))
        }

        $result = Remove-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'documents' -SnapshotName 'checkpoint' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'fssnapshot/5@checkpoint'
    }

    It 'restores a selected file-system snapshot through rollback' {
        Mock Get-DMFileSystemSnapshot {
            @([OceanstorFileSystemSnapshot]::new([pscustomobject]@{ ID = '5@checkpoint'; NAME = 'checkpoint'; PARENTID = '5'; PARENTNAME = 'documents'; vstoreId = '2' }, $script:session))
        }

        $result = Restore-DMFileSystemSnapshot -WebSession $script:session -FileSystemName 'documents' -SnapshotName 'checkpoint' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'fssnapshot/rollback_fssnapshot'
        $script:request.ID | Should -Be '5@checkpoint'
        $script:request.vstoreId | Should -Be '2'
    }

    It '<Command> respects WhatIf' -TestCases @(
        @{ Command = 'Remove-DMFileSystemSnapshot' }
        @{ Command = 'Restore-DMFileSystemSnapshot' }
    ) {
        param($Command)
        Mock Get-DMFileSystemSnapshot {
            @([OceanstorFileSystemSnapshot]::new([pscustomobject]@{ ID = '5@checkpoint'; NAME = 'checkpoint'; PARENTID = '5'; PARENTNAME = 'documents' }, $script:session))
        }

        $null = & $Command -WebSession $script:session -FileSystemName 'documents' -SnapshotName 'checkpoint' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
