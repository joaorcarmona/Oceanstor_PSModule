BeforeDiscovery {
    $script:storageMutationModule = New-Module -Name StorageMutationTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlun { param([pscustomobject]$WebSession) }
        function Get-DMlunGroup { param([pscustomobject]$WebSession) }
        function Get-DMhostbyName { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMhostGroup { param([pscustomobject]$WebSession) }
        function Get-DMFileSystem { param([pscustomobject]$WebSession) }
        function Get-DMShare { param([pscustomobject]$WebSession, [string]$ShareType) }
        function Get-DMnfsFileClient { param([pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorCIFSShare.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorDtree.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLun.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMFileSystem.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMDTree.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMNfsShare.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMNfsClient.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMCifsShare.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMCifsShare.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMdTree.ps1"

        Export-ModuleMember -Function 'Remove-DM*', 'New-DMCifsShare', 'New-DMdTree'
    }

    Import-Module $script:storageMutationModule -Force
}

AfterAll {
    Remove-Module -Name StorageMutationTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope StorageMutationTestModule {
Describe 'Storage and NAS removal commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlun { @([pscustomobject]@{ Id = 'lun-01'; Name = 'database' }) }
        Mock Get-DMlunGroup { @([pscustomobject]@{ Id = 'lg-01'; Name = 'database-group' }) }
        Mock Get-DMhostbyName { @([pscustomobject]@{ Id = 'host-01'; Name = 'esx01' } | Where-Object Name -EQ $Name) }
        Mock Get-DMhostGroup { @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster' }) }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' }) }
        Mock Get-DMShare {
            if ($ShareType -eq 'CIFS') { return @([pscustomobject]@{ Id = 'cifs-01'; Name = 'docs' }) }
            return @([pscustomobject]@{ Id = 'nfs-01'; 'Share Path' = '/documents/' })
        }
        Mock Get-DMnfsFileClient { @([pscustomobject]@{ Id = 'client-01'; Name = '10.0.0.0/24' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It '<Command> removes the resolved object through <Resource>' -TestCases @(
        @{ Command = 'Remove-DMLun'; Parameters = @{ LunName = 'database'; ImmediateDelete = $true; VstoreId = '7' }; Resource = 'lun/lun-01?isDelayDelete=false&vstoreId=7' }
        @{ Command = 'Remove-DMLunGroup'; Parameters = @{ LunGroupName = 'database-group'; VstoreId = '7' }; Resource = 'lungroup/lg-01?vstoreId=7' }
        @{ Command = 'Remove-DMHost'; Parameters = @{ HostName = 'esx01' }; Resource = 'host/host-01' }
        @{ Command = 'Remove-DMHostGroup'; Parameters = @{ HostGroupName = 'cluster' }; Resource = 'hostgroup/hg-01' }
        @{ Command = 'Remove-DMFileSystem'; Parameters = @{ FileSystemName = 'documents'; Force = $true; Worm = $true; VstoreId = '7' }; Resource = 'filesystem/fs-01?forceDeleteFs=true&SUBTYPE=1&vstoreId=7' }
        @{ Command = 'Remove-DMNfsShare'; Parameters = @{ SharePath = '/documents/'; PrivateShare = $true; VstoreId = '7' }; Resource = 'NFSSHARE/nfs-01?sharePrivate=1&vstoreId=7' }
        @{ Command = 'Remove-DMNfsClient'; Parameters = @{ ClientName = '10.0.0.0/24'; VstoreId = '7' }; Resource = 'NFS_SHARE_AUTH_CLIENT/client-01?vstoreId=7' }
        @{ Command = 'Remove-DMCifsShare'; Parameters = @{ ShareName = 'docs'; VstoreId = '7' }; Resource = 'CIFSSHARE/cifs-01?vstoreId=7' }
    ) {
        param($Command, $Parameters, $Resource)

        $result = & $Command -WebSession $script:session -Confirm:$false @Parameters

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be $Resource
    }

    It 'removes a dTree selected under its parent file system' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = '4097@17'; NAME = 'archive' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $result = Remove-DMDTree -WebSession $script:session -FileSystemName 'documents' -DTreeName 'archive' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'QUOTATREE/4097@17?vstoreId=7'
        Should -Invoke Invoke-DeviceManager -ParameterFilter { $Method -eq 'GET' -and $Resource -eq 'QUOTATREE?PARENTID=fs-01' } -Times 1 -Exactly
    }

    It 'rejects removal of an unknown LUN' {
        $result = Remove-DMLun -WebSession $script:session -LunName 'missing' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid LunName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'does not delete when WhatIf is specified' {
        $null = Remove-DMHost -WebSession $script:session -HostName 'esx01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'removes every host piped in, not just the last one' {
        Mock Get-DMhostbyName {
            @([pscustomobject]@{ Id = "host-$Name" ; Name = $Name })
        }

        $hosts = @([pscustomobject]@{ Name = 'esx01' }, [pscustomobject]@{ Name = 'esx02' })
        $null = $hosts | Remove-DMHost -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'host/host-esx01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'host/host-esx02' }
    }

    It 'removes every host group piped in, not just the last one' {
        Mock Get-DMhostGroup {
            @(
                [pscustomobject]@{ Id = 'hg-01'; Name = 'cluster-a' }
                [pscustomobject]@{ Id = 'hg-02'; Name = 'cluster-b' }
            )
        }

        $groups = @([pscustomobject]@{ Name = 'cluster-a' }, [pscustomobject]@{ Name = 'cluster-b' })
        $null = $groups | Remove-DMHostGroup -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'hostgroup/hg-01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'hostgroup/hg-02' }
    }

    It 'removes every file system piped in, not just the last one' {
        Mock Get-DMFileSystem {
            @(
                [pscustomobject]@{ Id = 'fs-01'; Name = 'fs-a' }
                [pscustomobject]@{ Id = 'fs-02'; Name = 'fs-b' }
            )
        }

        $items = @([pscustomobject]@{ Name = 'fs-a' }, [pscustomobject]@{ Name = 'fs-b' })
        $null = $items | Remove-DMFileSystem -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'filesystem/fs-01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'filesystem/fs-02' }
    }

    It 'removes every NFS share piped in by Share Path, not just the last one' {
        Mock Get-DMShare {
            @(
                [pscustomobject]@{ Id = 'nfs-01'; 'Share Path' = '/share-a/' }
                [pscustomobject]@{ Id = 'nfs-02'; 'Share Path' = '/share-b/' }
            )
        }

        $items = @([pscustomobject]@{ 'Share Path' = '/share-a/' }, [pscustomobject]@{ 'Share Path' = '/share-b/' })
        $null = $items | Remove-DMNfsShare -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'NFSSHARE/nfs-01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'NFSSHARE/nfs-02' }
    }
}

Describe 'New-DMCifsShare' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{
                    ID = 'cifs-01'; NAME = $BodyData.NAME; SHAREPATH = $BodyData.SHAREPATH
                    FSID = $BodyData.FSID; subType = $BodyData.subType; OFFLINEFILEMODE = $BodyData.OFFLINEFILEMODE
                }
            }
        }
    }

    It 'creates a CIFS share from a resolved file-system name' {
        $result = New-DMCifsShare -WebSession $script:session -ShareName 'docs' -FileSystemName 'documents' -Description 'Team files' -SubType Normal -OfflineFileMode Documents -EnableSmb3Encryption $true

        $result.GetType().Name | Should -Be 'OceanStorCIFSShare'
        $result.Id | Should -Be 'cifs-01'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'CIFSSHARE'
        $script:request.FSID | Should -Be 'fs-01'
        $script:request.SHAREPATH | Should -Be '/documents/'
        $script:request.DESCRIPTION | Should -Be 'Team files'
        $script:request.OFFLINEFILEMODE | Should -Be 2
        $script:request.smb3EncryptionEnable | Should -BeTrue
    }

    It 'rejects a reserved CIFS share name' {
        { New-DMCifsShare -WebSession $script:session -ShareName 'ipc$' -FileSystemName 'documents' } |
            Should -Throw '*ShareName is reserved*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}

Describe 'New-DMdTree' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{ ID = 'fs-01@4'; NAME = $BodyData.NAME; PARENTID = $BodyData.PARENTID }
            }
        }
    }

    It 'creates a dTree using a minimal parent-ID payload' {
        $result = New-DMdTree -WebSession $script:session -FileSystemId 'fs-01' -DTreeName 'archive'

        $result.GetType().Name | Should -Be 'OceanStorDtree'
        $result.Name | Should -Be 'archive'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'QUOTATREE'
        $script:request.PARENTID | Should -Be 'fs-01'
        $script:request.ContainsKey('path') | Should -BeFalse
        $script:request.ContainsKey('QUOTASWITCH') | Should -BeFalse
        $script:request.ContainsKey('nasLockingPolicy') | Should -BeFalse
    }

    It 'translates explicitly selected dTree settings to API values' {
        $null = New-DMdTree -WebSession $script:session -FileSystemId 'fs-01' -DTreeName 'archive' `
            -QuotaSwitch enabled -LockingPolicy Advisory -Path '/archive'

        $script:request.QUOTASWITCH | Should -BeTrue
        $script:request.nasLockingPolicy | Should -Be 1
        $script:request.path | Should -Be '/archive'
    }

    It 'rejects an unknown parent file system before creating a dTree' {
        { New-DMdTree -WebSession $script:session -FileSystemId 'missing' -DTreeName 'archive' } |
            Should -Throw '*Invalid FileSystemId*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
