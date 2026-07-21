BeforeDiscovery {
    $script:newLunModule = New-Module -Name NewDMLunTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMstoragePool {
            param([pscustomobject]$WebSession)
        }

        function Get-DMWorkLoadType {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv6.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\ConvertTo-DMCapacityBlock.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMLun.ps1"

        Export-ModuleMember -Function New-DMLun
    }

    Import-Module $script:newLunModule -Force
}

AfterAll {
    Remove-Module -Name NewDMLunTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewDMLunTestModule {
Describe 'New-DMLun' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMstoragePool {
            @([pscustomobject]@{ Id = 'pool-01'; Name = 'performance' })
        }
        Mock Get-DMWorkLoadType {
            @(
                [pscustomobject]@{ Id = '0'; Name = 'Default' }
                [pscustomobject]@{ Id = '8'; Name = 'Vmware_VDI' }
            )
        }
        Mock Invoke-DeviceManager {
            $script:lunRequest = $BodyData
            $script:lunMethod = $Method
            $script:lunResource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{
                    ID = 'lun-01'; NAME = 'data-lun'; PARENTID = 'pool-01'
                    PARENTNAME = 'performance'; TYPE = 11; SECTORSIZE = 512
                    CAPACITY = 2097152; ALLOCCAPACITY = 0; HEALTHSTATUS = 1
                    RUNNINGSTATUS = 27; ALLOCTYPE = 1; WWN = 'wwn-01'
                }
            }
        }
    }

    It 'creates a LUN in an existing storage pool' {
        $result = New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolID 'pool-01'

        $result.Id | Should -Be 'lun-01'
        $result.Name | Should -Be 'data-lun'
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
        $script:lunMethod | Should -Be 'POST'
        $script:lunResource | Should -Be 'lun'
        $script:lunRequest.PARENTID | Should -Be 'pool-01'
        # ALLOCTYPE is deprecated/removed on Dorado v6 and must never be sent in the create body.
        $script:lunRequest.ContainsKey('ALLOCTYPE') | Should -BeFalse
        $script:lunRequest.CAPACITY | Should -Be 2097152
    }

    It 'sends WRITEPOLICY (not the CACHETPOLICY typo) with the correct Dorado value' {
        # Default WriteBack -> 1
        New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolID 'pool-01'
        $script:lunRequest.ContainsKey('CACHETPOLICY') | Should -BeFalse
        $script:lunRequest.WRITEPOLICY | Should -Be 1

        # WriteThrough -> 2 (Dorado: 1 = write back, 2 = write through)
        New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolID 'pool-01' -writeCachePolicy WriteThrough
        $script:lunRequest.WRITEPOLICY | Should -Be 2
    }

    It 'resolves -StoragePoolName to its Id in PARENTID' {
        $result = New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolName 'performance'

        $result.Id | Should -Be 'lun-01'
        $script:lunRequest.PARENTID | Should -Be 'pool-01'
    }

    It 'resolves -WorkloadTypeName to its Id in WORKLOADTYPEID' {
        New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolName 'performance' -WorkloadTypeName 'Vmware_VDI'

        $script:lunRequest.WORKLOADTYPEID | Should -Be '8'
    }

    It 'rejects an invalid -StoragePoolName' {
        { New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolName 'does-not-exist' } |
            Should -Throw '*Invalid StoragePoolName*'
    }

    It 'rejects supplying both -WorkloadTypeName and -workloadTypeId' {
        { New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolName 'performance' -WorkloadTypeName 'Vmware_VDI' -workloadTypeId '0' } |
            Should -Throw '*not both*'
    }

    It 'converts <Capacity> to <ExpectedBlocks> 512-byte blocks' -ForEach @(
        @{ Capacity = '10MB';   ExpectedBlocks = 20480 }
        @{ Capacity = '10GB';   ExpectedBlocks = 20971520 }
        @{ Capacity = '1TB';    ExpectedBlocks = 2147483648 }
        @{ Capacity = '1.5GB';  ExpectedBlocks = 3145728 }
        @{ Capacity = '1,5GB';  ExpectedBlocks = 3145728 }
        @{ Capacity = '10 mb';  ExpectedBlocks = 20480 }
    ) {
        $null = New-DMLun -WebSession $script:session -LunName 'data-lun' -Capacity $Capacity -StoragePoolID 'pool-01'

        $script:lunRequest.CAPACITY | Should -Be $ExpectedBlocks
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'rejects invalid capacity <Capacity>' -ForEach @(
        @{ Capacity = '10XB' }
        @{ Capacity = '0MB' }
        @{ Capacity = '-1GB' }
        @{ Capacity = '0.0001MB' }
    ) {
        { New-DMLun -WebSession $script:session -LunName 'data-lun' -Capacity $Capacity -StoragePoolID 'pool-01' } |
            Should -Throw '*Capacity*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a storage pool identifier that does not exist' {
        { New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolID 'missing' } |
            Should -Throw '*Invalid StoragePoolID*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
