BeforeDiscovery {
    $script:newFileSystemModule = New-Module -Name NewDMFileSystemTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMstoragePool {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorFileSystem.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\ConvertTo-DMCapacityBlock.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMFileSystem.ps1"

        Export-ModuleMember -Function New-DMFileSystem
    }

    Import-Module $script:newFileSystemModule -Force
}

AfterAll {
    Remove-Module -Name NewDMFileSystemTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewDMFileSystemTestModule {
Describe 'New-DMFileSystem' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMstoragePool {
            @([pscustomobject]@{ Id = 0; Name = 'performance' })
        }
        Mock Invoke-DeviceManager {
            $script:fileSystemRequest = $BodyData
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0; Description = '' }
                data  = [pscustomobject]@{
                    ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512
                    CAPACITY = 2097152; ALLOCCAPACITY = '0'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27
                }
            }
        }
    }

    It 'converts <Capacity> to <ExpectedBlocks> 512-byte blocks' -ForEach @(
        @{ Capacity = '100MB';  ExpectedBlocks = 204800 }
        @{ Capacity = '10GB';   ExpectedBlocks = 20971520 }
        @{ Capacity = '1TB';    ExpectedBlocks = 2147483648 }
        @{ Capacity = '1.5GB';  ExpectedBlocks = 3145728 }
        @{ Capacity = '1,5GB';  ExpectedBlocks = 3145728 }
        @{ Capacity = 10;       ExpectedBlocks = 20971520 }
    ) {
        $null = New-DMFileSystem -WebSession $script:session -FileSystemName 'documents' -StoragePoolID 0 -Capacity $Capacity

        $script:fileSystemRequest.CAPACITY | Should -Be $ExpectedBlocks
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'omits capacity when the parameter is not supplied' {
        $null = New-DMFileSystem -WebSession $script:session -FileSystemName 'documents' -StoragePoolID 0

        $script:fileSystemRequest.ContainsKey('CAPACITY') | Should -BeFalse
    }

    It 'accepts FileSystemName and StoragePoolID as positional arguments' {
        $null = New-DMFileSystem $script:session 'documents' 0

        $script:fileSystemRequest.NAME | Should -Be 'documents'
        $script:fileSystemRequest.PARENTID | Should -Be 0
    }

    It 'rejects invalid capacity <Capacity>' -ForEach @(
        @{ Capacity = '10XB' }
        @{ Capacity = '0MB' }
        @{ Capacity = '-1GB' }
        @{ Capacity = '0.0001MB' }
    ) {
        { New-DMFileSystem -WebSession $script:session -FileSystemName 'documents' -StoragePoolID 0 -Capacity $Capacity } |
            Should -Throw '*Capacity*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
