BeforeDiscovery {
    $script:newLunModule = New-Module -Name NewDMLunTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function get-DMstoragePools {
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

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv6.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\new-DMLun.ps1"

        Export-ModuleMember -Function new-DMLun
    }

    Import-Module $script:newLunModule -Force
}

AfterAll {
    Remove-Module -Name NewDMLunTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewDMLunTestModule {
Describe 'new-DMLun' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock get-DMstoragePools {
            @([pscustomobject]@{ Id = 'pool-01'; Name = 'performance' })
        }
        Mock invoke-DeviceManager {
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
        $result = new-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolID 'pool-01' -allocType Thin

        $result.Id | Should -Be 'lun-01'
        $result.Name | Should -Be 'data-lun'
        Should -Invoke invoke-DeviceManager -Times 1 -Exactly
        $script:lunMethod | Should -Be 'POST'
        $script:lunResource | Should -Be 'lun'
        $script:lunRequest.PARENTID | Should -Be 'pool-01'
        $script:lunRequest.ALLOCTYPE | Should -Be 1
    }

    It 'rejects a storage pool identifier that does not exist' {
        { new-DMLun -WebSession $script:session -LunName 'data-lun' -capacity 2097152 -StoragePoolID 'missing' } |
            Should -Throw '*Invalid StoragePoolID*'

        Should -Invoke invoke-DeviceManager -Times 0 -Exactly
    }
}
}
