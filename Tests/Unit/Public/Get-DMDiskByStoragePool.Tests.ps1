BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMDiskByStoragePoolTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMstoragePool { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMparsedElabel { param([string]$eLabelString) }
        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorDisks.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMDiskByStoragePool.ps1"

        Export-ModuleMember -Function Get-DMDiskByStoragePool
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMDiskByStoragePoolTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMDiskByStoragePoolTestModule {
Describe 'Get-DMDiskByStoragePool' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:storagePool = [pscustomobject]@{ Id = 'pool-01'; Name = 'performance' }

        Mock Get-DMstoragePool {
            param($WebSession, $Name)
            $pools = @([pscustomobject]@{ Id = 'pool-01'; Name = 'performance' })
            if ($Name) { return @($pools | Where-Object Name -Like $Name) }
            $pools
        }
        Mock Get-DMparsedElabel { [pscustomobject]@{} }
    }

    It 'returns disks that are members of the pool when a StoragePool object is supplied' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'disk-01'; POOLID = 'pool-01'; POOLNAME = 'performance'; LOGICTYPE = 2; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 10; DISKTYPE = 14; DISKFORM = 3; barcode = '00PARTNUM01'; ELABEL = 'BoardType=board-01' }
                    [pscustomobject]@{ ID = 'disk-02'; POOLID = 'pool-02'; POOLNAME = 'capacity'; LOGICTYPE = 2; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 10; DISKTYPE = 14; DISKFORM = 3; barcode = '00PARTNUM01'; ELABEL = 'BoardType=board-01' }
                ) }
        }

        $result = @(Get-DMDiskByStoragePool -WebSession $script:session -StoragePool $script:storagePool)

        $result.Count | Should -Be 1
        $result[0].id | Should -Be 'disk-01'
    }

    It 'resolves the pool by name when StoragePoolName is supplied' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'disk-01'; POOLID = 'pool-01'; POOLNAME = 'performance'; LOGICTYPE = 2; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 10; DISKTYPE = 14; DISKFORM = 3; barcode = '00PARTNUM01'; ELABEL = 'BoardType=board-01' }
                ) }
        }

        $result = @(Get-DMDiskByStoragePool -WebSession $script:session -StoragePoolName 'performance')

        $result.Count | Should -Be 1
        $result[0].id | Should -Be 'disk-01'
    }

    It 'rejects a StoragePoolName that does not exist' {
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }

        { Get-DMDiskByStoragePool -WebSession $script:session -StoragePoolName 'missing' } |
            Should -Throw '*Invalid StoragePoolName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'resolves the pool by ID when StoragePoolId is supplied, without validating it first' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'disk-03'; POOLID = 'pool-99'; POOLNAME = 'archive'; LOGICTYPE = 2; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 10; DISKTYPE = 14; DISKFORM = 3; barcode = '00PARTNUM01'; ELABEL = 'BoardType=board-01' }
                ) }
        }

        $result = @(Get-DMDiskByStoragePool -WebSession $script:session -StoragePoolId 'pool-99')

        $result.Count | Should -Be 1
        $result[0].id | Should -Be 'disk-03'
        Should -Invoke Get-DMstoragePool -Times 0 -Exactly
    }

    It 'returns an empty array when the pool has no member disks' {
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }

        $result = Get-DMDiskByStoragePool -WebSession $script:session -StoragePool $script:storagePool

        @($result).Count | Should -Be 0
    }

    It 'exposes completion metadata for StoragePoolName' {
        $command = Get-Command Get-DMDiskByStoragePool
        @($command.Parameters['StoragePoolName'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
            Should -BeGreaterThan 0 -Because 'Get-DMDiskByStoragePool -StoragePoolName should support tab completion'
    }
}
}
