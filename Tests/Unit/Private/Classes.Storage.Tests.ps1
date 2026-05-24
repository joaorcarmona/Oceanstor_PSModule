BeforeAll {
    function global:new-DMLunSnapshot {}
    function global:get-DMLunSnapshots {}
    function global:remove-DMLunSnapShot {}
    function global:Enable-DMLunSnapshot {}
    function global:Restart-DMLunSnapshot {}
    function global:Resize-DMLunSnapshot {}
    function global:Restore-DMLunSnapshot {}

    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorCIFSShare.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorFileSystem.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorLunGroup.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv3.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv6.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunSnapshot.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorNFSclient.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorNFSShare.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLIF.ps1"
}

AfterAll {
    Remove-Item -LiteralPath 'Function:\global:new-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:get-DMLunSnapshots' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:remove-DMLunSnapShot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Enable-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Restart-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Resize-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Restore-DMLunSnapshot' -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotInvocation -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotQuery -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotRemoval -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LunSnapshotAction -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Storage and share model classes' {
    BeforeAll {
        $script:session = [pscustomobject]@{ Name = 'test-session' }
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

    It 'maps a LUN group' {
        $source = [pscustomobject]@{ ID = 12; NAME = 'application-luns'; APPTYPE = 1; GROUPTYPE = 0; CAPCITY = 1GB; ISADD2MAPPINGVIEW = 'false' }

        $result = New-Object -TypeName OceanStorLunGroup -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 12
        $result.'Application Type' | Should -Be 'Oracle'
        $result.'Is Mapped' | Should -BeFalse
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

    It 'creates a snapshot from a version 6 LUN object' {
        function global:new-DMLunSnapshot {
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
        function global:new-DMLunSnapshot {
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
        function global:get-DMLunSnapshots {
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
        function global:remove-DMLunSnapShot {
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
        function global:remove-DMLunSnapShot {
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

        $snapshot.Activacate().Code | Should -Be 0
        $global:LunSnapshotAction.Action | Should -Be 'Activate'
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
