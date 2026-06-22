BeforeDiscovery {
    $script:newLunModule = New-Module -Name NewDMLunTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMstoragePools {
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

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv6.ps1"
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
        Mock Get-DMstoragePools {
            @([pscustomobject]@{ Id = 'pool-01'; Name = 'performance' })
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
        $result = New-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolID 'pool-01' -allocType Thin

        $result.Id | Should -Be 'lun-01'
        $result.Name | Should -Be 'data-lun'
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
        $script:lunMethod | Should -Be 'POST'
        $script:lunResource | Should -Be 'lun'
        $script:lunRequest.PARENTID | Should -Be 'pool-01'
        $script:lunRequest.ALLOCTYPE | Should -Be 1
        $script:lunRequest.CAPACITY | Should -Be 2097152
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
