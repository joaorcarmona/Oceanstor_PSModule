BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHost.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHostGroup.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHostLink.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHostinitiatorFC.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHostinitiatorISCSI.ps1"
}

Describe 'Host model classes' {
    It 'maps a host and its operating system' {
        $source = [pscustomobject]@{ ID = 'host-01'; NAME = 'server01'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; OPERATIONSYSTEM = 7; TYPE = 21 }

        $result = New-Object -TypeName OceanStorHost -ArgumentList (,$source)

        $result.id | Should -Be 'host-01'
        $result.'Operation System' | Should -Be 'VMware ESX'
        $result.type | Should -Be 'Host'
    }

    It 'maps host group identity and mapping state' {
        $source = [pscustomobject]@{ ID = 4; NAME = 'cluster'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }

        $result = New-Object -TypeName OceanStorHostGroup -ArgumentList (,$source)

        $result.Id | Should -Be 4
        $result.Name | Should -Be 'cluster'
        $result.'Is Mapped' | Should -BeTrue
    }

    It 'maps an active host link' {
        $source = [pscustomobject]@{ ID = 'link-01'; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; TARGET_TYPE = 212; TYPE = 255 }

        $result = New-Object -TypeName OceanStorHostLink -ArgumentList (,$source)

        $result.Id | Should -Be 'link-01'
        $result.'Running Status' | Should -Be 'Link UP'
        $result.'Target Type' | Should -Be 'Fibre Channel Port'
    }

    It 'maps a fibre channel initiator' {
        $source = [pscustomobject]@{ ID = 'fc-01'; TYPE = 223; PARENTTYPE = 21; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; OPERATIONSYSTEM = 0; vstoreid = 4294967295 }

        $result = New-Object -TypeName OceanstorHostinitiatorFC -ArgumentList (,$source)

        $result.Id | Should -Be 'fc-01'
        $result.Type | Should -Be 'FC Initiator'
        $result.'Operating System' | Should -Be 'Linux'
        $result.'vStore ID' | Should -Be 4294967295
    }

    It 'maps an iSCSI initiator and CHAP state' {
        $source = [pscustomobject]@{ ID = 'iscsi-01'; TYPE = 222; PARENTTYPE = 21; USECHAP = $true; CHAPNAME = 'chap-user'; RUNNINGSTATUS = 27; vstoreid = 4294967295 }

        $result = New-Object -TypeName OceanstorHostinitiatorISCSI -ArgumentList (,$source)

        $result.Id | Should -Be 'iscsi-01'
        $result.Type | Should -Be 'ISCSI Initiator'
        $result.'Use CHAP' | Should -BeTrue
        $result.'vStore ID' | Should -Be 4294967295
    }
}
