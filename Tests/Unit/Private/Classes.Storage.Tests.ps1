BeforeAll {
    function global:New-DMLunSnapshot {}
    function global:New-DMLunSnapshotCopy {}
    function global:Get-DMLunSnapshot {}
    function global:Remove-DMLunSnapShot {}
    function global:Enable-DMLunSnapshot {}
    function global:Restart-DMLunSnapshot {}
    function global:Resize-DMLunSnapshot {}
    function global:Restore-DMLunSnapshot {}
    function global:New-DMFileSystemSnapshot {}
    function global:Get-DMFileSystemSnapshot {}
    function global:Remove-DMFileSystemSnapshot {}
    function global:Restore-DMFileSystemSnapshot {}
    function global:Set-DMLun {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [pscustomobject]$WebSession,
            [string]$LunName,
            [object]$Capacity,
            [string]$NewName
        )
        $global:LunModificationInvocation = [pscustomobject]@{
            WebSession = $WebSession; LunName = $LunName; Capacity = $Capacity; NewName = $NewName
        }
        [pscustomobject]@{ Code = 0 }
    }
    function global:Set-DMFileSystem {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [pscustomobject]$WebSession,
            [string]$FileSystemName,
            [object]$Capacity,
            [string]$NewName
        )
        $global:FileSystemModificationInvocation = [pscustomobject]@{
            WebSession = $WebSession; FileSystemName = $FileSystemName; Capacity = $Capacity; NewName = $NewName
        }
        [pscustomobject]@{ Code = 0 }
    }
    function global:ConvertTo-DMCapacityBlock {
        param([object]$Capacity, [string]$UnitlessUnit)
        switch ([string]$Capacity) {
            '512MB' { return 1048576 }
            '2GB' { return 4194304 }
            default { return [long]$Capacity }
        }
    }
    function global:Rename-DMLun {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param([pscustomobject]$WebSession, [string]$LunName, [string]$NewName)
        $global:LunModificationInvocation = [pscustomobject]@{
            WebSession = $WebSession; LunName = $LunName; NewName = $NewName
        }
        [pscustomobject]@{ Code = 0 }
    }
    function global:Rename-DMFileSystem {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param([pscustomobject]$WebSession, [string]$FileSystemName, [string]$NewName)
        $global:FileSystemModificationInvocation = [pscustomobject]@{
            WebSession = $WebSession; FileSystemName = $FileSystemName; NewName = $NewName
        }
        [pscustomobject]@{ Code = 0 }
    }
    function global:Rename-DMHost {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param([pscustomobject]$WebSession, [string]$HostName, [string]$NewName)
        $global:NamedObjectRenameInvocation = [pscustomobject]@{ Type = 'Host'; Name = $HostName; NewName = $NewName; WebSession = $WebSession }
        [pscustomobject]@{ Code = 0 }
    }
    function global:Rename-DMHostGroup {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param([pscustomobject]$WebSession, [string]$HostGroupName, [string]$NewName)
        $global:NamedObjectRenameInvocation = [pscustomobject]@{ Type = 'HostGroup'; Name = $HostGroupName; NewName = $NewName; WebSession = $WebSession }
        [pscustomobject]@{ Code = 0 }
    }
    function global:Rename-DMLunGroup {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param([pscustomobject]$WebSession, [string]$LunGroupName, [string]$NewName)
        $global:NamedObjectRenameInvocation = [pscustomobject]@{ Type = 'LunGroup'; Name = $LunGroupName; NewName = $NewName; WebSession = $WebSession }
        [pscustomobject]@{ Code = 0 }
    }
    function global:Rename-DMPortGroup {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param([pscustomobject]$WebSession, [string]$PortGroupName, [string]$NewName)
        $global:NamedObjectRenameInvocation = [pscustomobject]@{ Type = 'PortGroup'; Name = $PortGroupName; NewName = $NewName; WebSession = $WebSession }
        [pscustomobject]@{ Code = 0 }
    }

    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorCIFSShare.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorFileSystem.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHost.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHostGroup.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorLunGroup.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPortGroup.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv3.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv6.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunSnapshot.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorFileSystemSnapshot.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorNFSclient.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorNFSShare.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLIF.ps1"
}

AfterAll {
    Remove-Item -LiteralPath 'Function:\global:New-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:New-DMLunSnapshotCopy' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Get-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Remove-DMLunSnapShot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Enable-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Restart-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Resize-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Restore-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:New-DMFileSystemSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Get-DMFileSystemSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Remove-DMFileSystemSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Restore-DMFileSystemSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Set-DMLun' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Set-DMFileSystem' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:ConvertTo-DMCapacityBlock' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Rename-DMLun' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Rename-DMFileSystem' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Rename-DMHost' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Rename-DMHostGroup' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Rename-DMLunGroup' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Rename-DMPortGroup' -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotInvocation -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotQuery -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotRemoval -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotAction -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotCopyInvocation -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name FileSystemSnapshotInvocation -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name FileSystemSnapshotQuery -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name FileSystemSnapshotAction -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LunModificationInvocation -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name FileSystemModificationInvocation -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name NamedObjectRenameInvocation -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Storage and share model classes' {
    BeforeAll {
        $script:session = [pscustomobject]@{ Name = 'Test-session' }
    }

    It 'maps CIFS share policy flags' {
        $source = [pscustomobject]@{ ID = 'cifs-01'; NAME = 'share'; subType = 0; ABEENABLE = $true; ENABLEOPLOCK = $false; OFFLINEFILEMODE = 1 }

        $result = New-Object -TypeName OceanStorCIFSShare -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'cifs-01'
        $result.'Enable ABE' | Should -Be 'enabled'
        $result.'Offline File Mode' | Should -Be 'manual'
        $result.Session | Should -Be $script:session
    }

    It 'maps a file system and converts capacity' {
        $source = [pscustomobject]@{
            ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = '0'
            HEALTHSTATUS = 1; RUNNINGSTATUS = 27; ALLOCTYPE = 1; PARENTTYPE = 216
        }

        $result = New-Object -TypeName OceanstorFileSystem -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'fs-01'
        $result.'Capacity (GB)' | Should -Be 1
        $result.'Running Status' | Should -Be 'Online'
    }

    It 'creates and retrieves snapshots from a file-system object' {
        function global:New-DMFileSystemSnapshot {
            param([pscustomobject]$WebSession, [string]$SnapshotName, [string]$FileSystemName)
            $global:FileSystemSnapshotInvocation = [pscustomobject]@{
                WebSession = $WebSession; SnapshotName = $SnapshotName; FileSystemName = $FileSystemName
            }
            [pscustomobject]@{ Id = 'fs-snap-01' }
        }
        function global:Get-DMFileSystemSnapshot {
            param([pscustomobject]$WebSession, [string]$FileSystemName)
            $global:FileSystemSnapshotQuery = [pscustomobject]@{
                WebSession = $WebSession; FileSystemName = $FileSystemName
            }
            @([pscustomobject]@{ Id = 'fs-snap-01' })
        }
        $source = [pscustomobject]@{ ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = '0' }
        $fileSystem = New-Object -TypeName OceanstorFileSystem -ArgumentList @($source, $script:session)

        $fileSystem.NewSnapshot('checkpoint').Id | Should -Be 'fs-snap-01'
        $fileSystem.GetSnapshots().Id | Should -Be 'fs-snap-01'
        $global:FileSystemSnapshotInvocation.FileSystemName | Should -Be 'documents'
        $global:FileSystemSnapshotInvocation.SnapshotName | Should -Be 'checkpoint'
        $global:FileSystemSnapshotQuery.WebSession | Should -Be $script:session
    }

    It 'deletes and rolls back a file-system snapshot object' {
        function global:Remove-DMFileSystemSnapshot {
            param([pscustomobject]$WebSession, [string]$FileSystemName, [string]$SnapshotName)
            $global:FileSystemSnapshotAction = [pscustomobject]@{
                Action = 'Delete'; WebSession = $WebSession; FileSystemName = $FileSystemName; SnapshotName = $SnapshotName
            }
            [pscustomobject]@{ Code = 0 }
        }
        function global:Restore-DMFileSystemSnapshot {
            param([pscustomobject]$WebSession, [string]$FileSystemName, [string]$SnapshotName)
            $global:FileSystemSnapshotAction = [pscustomobject]@{
                Action = 'Rollback'; WebSession = $WebSession; FileSystemName = $FileSystemName; SnapshotName = $SnapshotName
            }
            [pscustomobject]@{ Code = 0 }
        }
        $source = [pscustomobject]@{ ID = '5@checkpoint'; NAME = 'checkpoint'; PARENTID = '5'; PARENTNAME = 'documents' }
        $snapshot = New-Object -TypeName OceanstorFileSystemSnapshot -ArgumentList @($source, $script:session)

        $snapshot.Delete().Code | Should -Be 0
        $global:FileSystemSnapshotAction.Action | Should -Be 'Delete'
        $snapshot.Rollback().Code | Should -Be 0
        $global:FileSystemSnapshotAction.Action | Should -Be 'Rollback'
        $global:FileSystemSnapshotAction.FileSystemName | Should -Be 'documents'
        $global:FileSystemSnapshotAction.SnapshotName | Should -Be 'checkpoint'
    }

    It 'maps a LUN group' {
        $source = [pscustomobject]@{ ID = 12; NAME = 'application-luns'; APPTYPE = 1; GROUPTYPE = 0; CAPCITY = 1GB; ISADD2MAPPINGVIEW = 'false' }

        $result = New-Object -TypeName OceanStorLunGroup -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 12
        $result.'Application Type' | Should -Be 'Oracle'
        $result.'Is Mapped' | Should -BeFalse
    }

    It 'renames host and group objects through their public commands' {
        $cases = @(
            @{
                Type = 'OceanStorHost'
                Source = [pscustomobject]@{ ID = 'host-01'; NAME = 'host-old'; TYPE = 21 }
                ExpectedType = 'Host'
            },
            @{
                Type = 'OceanStorHostGroup'
                Source = [pscustomobject]@{ ID = 1; NAME = 'hostgroup-old'; TYPE = 0 }
                ExpectedType = 'HostGroup'
            },
            @{
                Type = 'OceanStorLunGroup'
                Source = [pscustomobject]@{ ID = 2; NAME = 'lungroup-old'; GROUPTYPE = 0; CAPCITY = 0 }
                ExpectedType = 'LunGroup'
            },
            @{
                Type = 'OceanstorPortGroup'
                Source = [pscustomobject]@{ ID = 'pg-01'; NAME = 'portgroup-old'; portType = 0; isAddToMappingView = $false }
                ExpectedType = 'PortGroup'
            }
        )

        foreach ($case in $cases) {
            $object = New-Object -TypeName $case.Type -ArgumentList @($case.Source, $script:session)
            $oldName = $object.Name
            $newName = "$oldName-new"

            $object.Rename($newName).Code | Should -Be 0
            $global:NamedObjectRenameInvocation.Type | Should -Be $case.ExpectedType
            $global:NamedObjectRenameInvocation.Name | Should -Be $oldName
            $global:NamedObjectRenameInvocation.NewName | Should -Be $newName
            $global:NamedObjectRenameInvocation.WebSession | Should -Be $script:session
            $object.Name | Should -Be $newName
        }
    }

    It 'maps a version 3 LUN' {
        $source = [pscustomobject]@{ ID = 'lun-v3'; NAME = 'legacy'; TYPE = 11; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = 1048576; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; ALLOCTYPE = 1 }

        $result = New-Object -TypeName OceanstorLunv3 -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'lun-v3'
        $result.'Lun Size' | Should -Be 1
        $result.'Health Status' | Should -Be 'Normal'
    }

    It 'maps a version 6 LUN' {
        $source = [pscustomobject]@{ ID = 'lun-v6'; NAME = 'modern'; TYPE = 11; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = 1048576; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; ALLOCTYPE = 1; mapped = $true }

        $result = New-Object -TypeName OceanstorLunv6 -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'lun-v6'
        $result.'Lun Size' | Should -Be 1
        $result.Mapped | Should -Be 'yes'
    }

    It 'expands and renames from a version 6 LUN object' {
        $source = [pscustomobject]@{ ID = 'lun-v6'; NAME = 'modern'; TYPE = 11; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = 1048576; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; ALLOCTYPE = 1 }
        $lun = New-Object -TypeName OceanstorLunv6 -ArgumentList @($source, $script:session)

        $lun.Expand('2GB').Code | Should -Be 0
        $global:LunModificationInvocation.WebSession | Should -Be $script:session
        $global:LunModificationInvocation.LunName | Should -Be 'modern'
        $global:LunModificationInvocation.Capacity | Should -Be '2GB'

        $lun.Rename('modern-prod').Code | Should -Be 0
        $global:LunModificationInvocation.NewName | Should -Be 'modern-prod'
        $lun.Name | Should -Be 'modern-prod'
    }

    It 'exposes unsupported modification methods on a version 3 LUN object' {
        $source = [pscustomobject]@{ ID = 'lun-v3'; NAME = 'legacy'; TYPE = 11; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = 1048576; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; ALLOCTYPE = 1 }
        $lun = New-Object -TypeName OceanstorLunv3 -ArgumentList @($source, $script:session)

        { $lun.Expand('2GB') } | Should -Throw '*only for OceanStor Dorado V6*'
        { $lun.Rename('legacy-new') } | Should -Throw '*only for OceanStor Dorado V6*'
    }

    It 'expands and renames from a file-system object' {
        $source = [pscustomobject]@{ ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = '0' }
        $fileSystem = New-Object -TypeName OceanstorFileSystem -ArgumentList @($source, $script:session)

        $fileSystem.Expand('2GB').Code | Should -Be 0
        $global:FileSystemModificationInvocation.WebSession | Should -Be $script:session
        $global:FileSystemModificationInvocation.FileSystemName | Should -Be 'documents'
        $global:FileSystemModificationInvocation.Capacity | Should -Be '2GB'

        $fileSystem.Rename('documents-prod').Code | Should -Be 0
        $global:FileSystemModificationInvocation.NewName | Should -Be 'documents-prod'
        $fileSystem.Name | Should -Be 'documents-prod'
    }

    It 'rejects a non-expanding file-system object capacity' {
        $source = [pscustomobject]@{ ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = '0' }
        $fileSystem = New-Object -TypeName OceanstorFileSystem -ArgumentList @($source, $script:session)

        { $fileSystem.Expand('512MB') } | Should -Throw '*must be greater*'
    }

    It 'creates a snapshot from a version 6 LUN object' {
        function global:New-DMLunSnapshot {
            param(
                [pscustomobject]$WebSession,
                [string]$SnapshotName,
                [string]$SourceLunName,
                [string]$Description,
                [switch]$ReadOnly
            )

            $global:LunSnapshotInvocation = [pscustomobject]@{
                WebSession = $WebSession
                SnapshotName = $SnapshotName
                SourceLunName = $SourceLunName
                Description = $Description
                ReadOnly = $ReadOnly.IsPresent
            }

            [pscustomobject]@{ Id = 'snap-01'; Name = $SnapshotName }
        }
        $source = [pscustomobject]@{ ID = 'lun-v6'; NAME = 'modern'; TYPE = 11; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = 1048576; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; ALLOCTYPE = 1 }
        $lun = New-Object -TypeName OceanstorLunv6 -ArgumentList @($source, $script:session)

        $result = $lun.NewSnapShot('before-patch', 'Patch checkpoint', $true)

        $result.Id | Should -Be 'snap-01'
        $global:LunSnapshotInvocation.WebSession | Should -Be $script:session
        $global:LunSnapshotInvocation.SnapshotName | Should -Be 'before-patch'
        $global:LunSnapshotInvocation.SourceLunName | Should -Be 'modern'
        $global:LunSnapshotInvocation.Description | Should -Be 'Patch checkpoint'
        $global:LunSnapshotInvocation.ReadOnly | Should -BeTrue
    }

    It 'creates a snapshot with an automatically generated name from a version 6 LUN object' {
        function global:New-DMLunSnapshot {
            param(
                [pscustomobject]$WebSession,
                [string]$SnapshotName,
                [string]$SourceLunName
            )

            $global:LunSnapshotInvocation = [pscustomobject]@{
                WebSession = $WebSession
                SnapshotName = $SnapshotName
                SourceLunName = $SourceLunName
            }

            [pscustomobject]@{ Id = 'snap-02' }
        }
        $source = [pscustomobject]@{ ID = 'lun-v6'; NAME = 'modern'; TYPE = 11; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = 1048576; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; ALLOCTYPE = 1 }
        $lun = New-Object -TypeName OceanstorLunv6 -ArgumentList @($source, $script:session)

        $result = $lun.NewSnapShot()

        $result.Id | Should -Be 'snap-02'
        $global:LunSnapshotInvocation.WebSession | Should -Be $script:session
        $global:LunSnapshotInvocation.SourceLunName | Should -Be 'modern'
        $global:LunSnapshotInvocation.SnapshotName | Should -BeNullOrEmpty
    }

    It 'retrieves snapshots for a version 6 LUN object' {
        function global:Get-DMLunSnapshot {
            param(
                [pscustomobject]$WebSession,
                [string]$LunName
            )

            $global:LunSnapshotQuery = [pscustomobject]@{
                WebSession = $WebSession
                LunName = $LunName
            }

            @(
                [pscustomobject]@{ Id = 'snap-01' }
                [pscustomobject]@{ Id = 'snap-02' }
            )
        }
        $source = [pscustomobject]@{ ID = 'lun-v6'; NAME = 'modern'; TYPE = 11; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = 1048576; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; ALLOCTYPE = 1 }
        $lun = New-Object -TypeName OceanstorLunv6 -ArgumentList @($source, $script:session)

        $result = $lun.GetSnapShots()

        $result.Id | Should -Be @('snap-01', 'snap-02')
        $global:LunSnapshotQuery.WebSession | Should -Be $script:session
        $global:LunSnapshotQuery.LunName | Should -Be 'modern'
    }

    It 'deletes a LUN snapshot object and invalidates it after success' {
        function global:Remove-DMLunSnapShot {
            param(
                [pscustomobject]$WebSession,
                [string]$SnapShotName
            )

            $global:LunSnapshotRemoval = [pscustomobject]@{
                WebSession = $WebSession
                SnapShotName = $SnapShotName
            }

            [pscustomobject]@{ Code = 0 }
        }
        $source = [pscustomobject]@{
            ID = 'snap-01'; NAME = 'before-patch'; DESCRIPTION = 'Checkpoint'
            SOURCELUNID = 'lun-v6'; SOURCELUNNAME = 'modern'; HEALTHSTATUS = 1
            RUNNINGSTATUS = 43; USERCAPACITY = 2097152; CONSUMEDCAPACITY = 1024
            IOPRIORITY = 2; isReadOnly = $true; WWN = 'snapshot-wwn'
        }
        $snapshot = New-Object -TypeName OceanstorLunSnapshot -ArgumentList @($source, $script:session)

        $result = $snapshot.DeleteSnapShot()

        $result.Code | Should -Be 0
        $global:LunSnapshotRemoval.WebSession | Should -Be $script:session
        $global:LunSnapshotRemoval.SnapShotName | Should -Be 'before-patch'
        $snapshot.Id | Should -BeNullOrEmpty
        $snapshot.Name | Should -BeNullOrEmpty
        $snapshot.Session | Should -BeNullOrEmpty
    }

    It 'keeps a LUN snapshot object when deletion does not succeed' {
        function global:Remove-DMLunSnapShot {
            param(
                [pscustomobject]$WebSession,
                [string]$SnapShotName
            )

            [pscustomobject]@{ Code = 1 }
        }
        $source = [pscustomobject]@{ ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-v6'; SOURCELUNNAME = 'modern' }
        $snapshot = New-Object -TypeName OceanstorLunSnapshot -ArgumentList @($source, $script:session)

        $result = $snapshot.DeleteSnapShot()

        $result.Code | Should -Be 1
        $snapshot.Id | Should -Be 'snap-01'
        $snapshot.Name | Should -Be 'before-patch'
        $snapshot.Session | Should -Be $script:session
    }

    It 'activates a LUN snapshot object with both method spellings' {
        function global:Enable-DMLunSnapshot {
            param([pscustomobject]$WebSession, [string]$SnapShotName)

            $global:LunSnapshotAction = [pscustomobject]@{
                Action = 'Activate'; WebSession = $WebSession; SnapShotName = $SnapShotName
            }

            [pscustomobject]@{ Code = 0 }
        }
        $source = [pscustomobject]@{ ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-v6'; SOURCELUNNAME = 'modern' }
        $snapshot = New-Object -TypeName OceanstorLunSnapshot -ArgumentList @($source, $script:session)

        $snapshot.Activate().Code | Should -Be 0
        $global:LunSnapshotAction.Action | Should -Be 'Activate'
        $global:LunSnapshotAction.WebSession | Should -Be $script:session
        $global:LunSnapshotAction.SnapShotName | Should -Be 'before-patch'
    }

    It 'reactivates a LUN snapshot object' {
        function global:Restart-DMLunSnapshot {
            param([pscustomobject]$WebSession, [string]$SnapShotName)

            $global:LunSnapshotAction = [pscustomobject]@{
                Action = 'Reactivate'; WebSession = $WebSession; SnapShotName = $SnapShotName
            }

            [pscustomobject]@{ Code = 0 }
        }
        $source = [pscustomobject]@{ ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-v6'; SOURCELUNNAME = 'modern' }
        $snapshot = New-Object -TypeName OceanstorLunSnapshot -ArgumentList @($source, $script:session)

        $snapshot.Reactivate().Code | Should -Be 0
        $global:LunSnapshotAction.Action | Should -Be 'Reactivate'
        $global:LunSnapshotAction.WebSession | Should -Be $script:session
        $global:LunSnapshotAction.SnapShotName | Should -Be 'before-patch'
    }

    It 'expands a LUN snapshot object using sector capacity' {
        function global:Resize-DMLunSnapshot {
            param([pscustomobject]$WebSession, [string]$SnapShotName, [uint64]$UserCapacity)

            $global:LunSnapshotAction = [pscustomobject]@{
                Action = 'Expand'; WebSession = $WebSession; SnapShotName = $SnapShotName; UserCapacity = $UserCapacity
            }

            [pscustomobject]@{ Code = 0 }
        }
        $source = [pscustomobject]@{ ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-v6'; SOURCELUNNAME = 'modern' }
        $snapshot = New-Object -TypeName OceanstorLunSnapshot -ArgumentList @($source, $script:session)

        $snapshot.Expand(10485760).Code | Should -Be 0
        $global:LunSnapshotAction.Action | Should -Be 'Expand'
        $global:LunSnapshotAction.UserCapacity | Should -Be 10485760
    }

    It 'rolls back a LUN snapshot object with default and selected speed' {
        function global:Restore-DMLunSnapshot {
            param([pscustomobject]$WebSession, [string]$SnapShotName, [string]$RollbackSpeed)

            $global:LunSnapshotAction = [pscustomobject]@{
                Action = 'Rollback'; WebSession = $WebSession; SnapShotName = $SnapShotName; RollbackSpeed = $RollbackSpeed
            }

            [pscustomobject]@{ Code = 0 }
        }
        $source = [pscustomobject]@{ ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-v6'; SOURCELUNNAME = 'modern' }
        $snapshot = New-Object -TypeName OceanstorLunSnapshot -ArgumentList @($source, $script:session)

        $snapshot.Rollback().Code | Should -Be 0
        $global:LunSnapshotAction.RollbackSpeed | Should -BeNullOrEmpty

        $snapshot.Rollback('High').Code | Should -Be 0
        $global:LunSnapshotAction.Action | Should -Be 'Rollback'
        $global:LunSnapshotAction.RollbackSpeed | Should -Be 'High'
    }

    It 'creates a copy from a LUN snapshot object with the default name behavior' {
        function global:New-DMLunSnapshotCopy {
            param(
                [pscustomobject]$WebSession,
                [string]$SourceSnapShotName,
                [string]$SnapshotCopyName
            )

            $global:LunSnapshotCopyInvocation = [pscustomobject]@{
                WebSession = $WebSession
                SourceSnapShotName = $SourceSnapShotName
                SnapshotCopyName = $SnapshotCopyName
            }

            [pscustomobject]@{ Id = 'snap-copy-01' }
        }
        $source = [pscustomobject]@{ ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-v6'; SOURCELUNNAME = 'modern' }
        $snapshot = New-Object -TypeName OceanstorLunSnapshot -ArgumentList @($source, $script:session)

        $snapshot.CreateCopy().Id | Should -Be 'snap-copy-01'
        $global:LunSnapshotCopyInvocation.WebSession | Should -Be $script:session
        $global:LunSnapshotCopyInvocation.SourceSnapShotName | Should -Be 'before-patch'
        $global:LunSnapshotCopyInvocation.SnapshotCopyName | Should -BeNullOrEmpty
    }

    It 'creates a named copy from a LUN snapshot object with a description' {
        function global:New-DMLunSnapshotCopy {
            param(
                [pscustomobject]$WebSession,
                [string]$SourceSnapShotName,
                [string]$SnapshotCopyName,
                [string]$Description
            )

            $global:LunSnapshotCopyInvocation = [pscustomobject]@{
                WebSession = $WebSession
                SourceSnapShotName = $SourceSnapShotName
                SnapshotCopyName = $SnapshotCopyName
                Description = $Description
            }

            [pscustomobject]@{ Id = 'snap-copy-02' }
        }
        $source = [pscustomobject]@{ ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-v6'; SOURCELUNNAME = 'modern' }
        $snapshot = New-Object -TypeName OceanstorLunSnapshot -ArgumentList @($source, $script:session)

        $snapshot.CreateCopy('copy-name', 'Copy checkpoint').Id | Should -Be 'snap-copy-02'
        $global:LunSnapshotCopyInvocation.SourceSnapShotName | Should -Be 'before-patch'
        $global:LunSnapshotCopyInvocation.SnapshotCopyName | Should -Be 'copy-name'
        $global:LunSnapshotCopyInvocation.Description | Should -Be 'Copy checkpoint'
    }

    It 'maps an NFS client access policy' {
        $source = [pscustomobject]@{ ID = 'client-01'; NAME = '10.0.0.0/24'; ACCESSVAL = 1; SYNC = 0; CHARSET = 0; securityType = 0 }

        $result = New-Object -TypeName OceanstorNFSclient -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'client-01'
        $result.'Access Permission' | Should -Be 'read and write'
        $result.'Charset Encoding' | Should -Be 'UTF-8'
    }

    It 'maps an NFS share' {
        $source = [pscustomobject]@{ ID = 'nfs-01'; NAME = 'exports'; CHARACTERENCODING = 0; ENABLESHOWSNAPSHOT = $true; LOCKPOLICY = 1 }

        $result = New-Object -TypeName OceanStorNFSShare -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'nfs-01'
        $result.'Character Enconding' | Should -Be 'UTF-8'
        $result.'NFS Lock Policy' | Should -Be 'Mandatory Locking'
    }

    It 'maps a logical interface' {
        $source = [pscustomobject]@{ ID = 'lif-01'; NAME = 'service'; ADDRESSFAMILY = 0; IPV4ADDR = '10.1.1.10'; ROLE = 2; RUNNINGSTATUS = 10; SUPPORTPROTOCOL = 3 }

        $result = New-Object -TypeName OceanStorLIF -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'lif-01'
        $result.'Address Family' | Should -Be 'IPv4'
        $result.'Support Protocol' | Should -Be 'NFS+CIFS'
    }
}
