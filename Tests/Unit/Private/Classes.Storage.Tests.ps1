BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorCIFSShare.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorFileSystem.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorLunGroup.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv3.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv6.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorNFSclient.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorNFSShare.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLIF.ps1"
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
