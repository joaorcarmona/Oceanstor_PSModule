BeforeDiscovery {
    $script:newHostGroupModule = New-Module -Name NewHostGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMLunGroup.ps1"

        Export-ModuleMember -Function 'New-DMHost', 'New-DMHostGroup', 'New-DMLunGroup'
    }

    Import-Module $script:newHostGroupModule -Force
}

AfterAll {
    Remove-Module -Name NewHostGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewHostGroupTestModule {
Describe 'Create host and group commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:hostData = [pscustomobject]@{
            ID = 'host-01'; NAME = 'server01'; TYPE = 21; OPERATIONSYSTEM = 7
            DESCRIPTION = 'integration host'; vstoreid = 7; vstoreName = 'tenant-a'
        }
        $script:hostGroupData = [pscustomobject]@{
            ID = 14; NAME = 'cluster01'; TYPE = 0; DESCRIPTION = 'integration group'
            ISADD2MAPPINGVIEW = 'false'; vstoreid = 7; vstoreName = 'tenant-a'
        }
        $script:lunGroupData = [pscustomobject]@{
            ID = 256; NAME = 'database_luns'; GROUPTYPE = 0; APPTYPE = 3
            DESCRIPTION = 'integration group'; ISADD2MAPPINGVIEW = 'false'
            CAPCITY = 0; vstoreid = 7; vstoreName = 'tenant-a'
        }
    }

    It 'creates a host with the selected operating system' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $script:hostData }
        }

        $result = New-DMHost -WebSession $script:session -Name 'server01' -OperatingSystem 'VMware ESX' `
            -Description 'integration host' -VstoreId '7'

        $result.GetType().Name | Should -Be 'OceanStorHost'
        $result.Name | Should -Be 'server01'
        $result.'Operation System' | Should -Be 'VMware ESX'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'host'
        $script:request.TYPE | Should -Be 21
        $script:request.OPERATIONSYSTEM | Should -Be 7
        $script:request.DESCRIPTION | Should -Be 'integration host'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'creates a host group with the REST host-group type' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $script:hostGroupData }
        }

        $result = New-DMHostGroup -WebSession $script:session -Name 'cluster01' -Description 'integration group' -VstoreId '7'

        $result.GetType().Name | Should -Be 'OceanStorHostGroup'
        $result.Name | Should -Be 'cluster01'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'hostgroup'
        $script:request.TYPE | Should -Be 14
        $script:request.DESCRIPTION | Should -Be 'integration group'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'creates a LUN group with the selected application type' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $script:lunGroupData }
        }

        $result = New-DMLunGroup -WebSession $script:session -Name 'database_luns' -ApplicationType 'SQL Server' `
            -Description 'integration group' -VstoreId '7'

        $result.GetType().Name | Should -Be 'OceanStorLunGroup'
        $result.Name | Should -Be 'database_luns'
        $result.'Application Type' | Should -Be 'SQL Server'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'lungroup'
        $script:request.GROUPTYPE | Should -Be 0
        $script:request.APPTYPE | Should -Be 3
        $script:request.DESCRIPTION | Should -Be 'integration group'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'throws a descriptive error when host creation fails' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 1; Description = 'duplicate name' } }
        }

        { New-DMHost -WebSession $script:session -Name 'server01' } |
            Should -Throw '*duplicate name*'
    }
}
}
