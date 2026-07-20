BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorBBU.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorController.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorDisks.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorEnclosure.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorInterfaceModule.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPortBond.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorPortEth.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorPortFc.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPortSAS.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorvlLan.ps1"
}

Describe 'Hardware model classes' {
    BeforeAll {
        $script:session = [pscustomobject]@{ Name = 'Test-session' }
        $script:eLabel = @(
            'BoardType=board-01'
            'BarCode=serial-01'
            'Item=part-01'
            'Description=component'
            'Manufactured=2026-01-01'
            'VendorName=Huawei'
        ) -join "`n"
    }

    It 'maps a battery backup unit and parsed label data' {
        $source = [pscustomobject]@{ ID = 'bbu-01'; PARENTTYPE = 207; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 210; VOLTAGE = 120; REMAINLIFEDAYS = 30 }

        $result = New-Object -TypeName OceanStorBBU -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'bbu-01'
        $result.'PSU Type' | Should -Be 'BBU'
        $result.ESN | Should -Be 'serial-01'
        $result.voltage | Should -Be 12
        $result.Session | Should -Be $script:session
    }

    It 'maps a controller and parsed label data' {
        $source = [pscustomobject]@{ ID = 'ctrl-01'; NAME = 'A'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; ISMASTER = $true; RUNNINGSTATUS = 27; TYPE = 207; MEMORYSIZE = 1GB }

        $result = New-Object -TypeName OceanStorController -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'ctrl-01'
        $result.'Is Master' | Should -Be 'primary'
        $result.'Board Type' | Should -Be 'board-01'
    }

    It 'maps a disk and parsed label data' {
        $source = [pscustomobject]@{
            ID = 'disk-01'; barcode = '00PARTNUM01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1
            RUNNINGSTATUS = 27; TYPE = 10; DISKTYPE = 14; DISKFORM = 3; ISCOFFERDISK = 'FALSE'; manuCapacity = 1GB
        }

        $result = New-Object -TypeName OceanStorDisks -ArgumentList @($source, $script:session)

        $result.id | Should -Be 'disk-01'
        $result.'Disk Type' | Should -Be 'NVMe SSD'
        $result.'Part Number' | Should -Be 'part-01'
    }

    It 'maps an enclosure and parsed label data' {
        $source = [pscustomobject]@{ ID = 'enc-01'; NAME = 'DAE'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 206; MODEL = 17 }

        $result = New-Object -TypeName OceanStorEnclosure -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'enc-01'
        $result.Type | Should -Be 'enclosure'
        $result.'Bar Code' | Should -Be 'serial-01'
    }

    It 'maps an interface module and parsed label data' {
        $source = [pscustomobject]@{ ID = 'module-01'; NAME = 'IOM'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 209; MODEL = 2307 }

        $result = New-Object -TypeName OceanstorInterfaceModule -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'module-01'
        $result.Type | Should -Be 'Interface Module'
        $result.'Part Number' | Should -Be 'part-01'
    }

    It 'maps a bonded Ethernet port' {
        $source = [pscustomobject]@{ ID = 'bond-01'; NAME = 'bond0'; TYPE = 235; HEALTHSTATUS = 1; RUNNINGSTATUS = 10 }

        $result = New-Object -TypeName OceanStorPortBond -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'bond-01'
        $result.Name | Should -Be 'bond0'
        $result.'Port Type' | Should -Be 'Bond Port'
    }

    It 'decodes a JSON-encoded PORTIDLIST into plain member port IDs' {
        $source = [pscustomobject]@{ ID = 'bond-01'; NAME = 'bond0'; TYPE = 235; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; PORTIDLIST = '["1211","1212"]' }

        $result = New-Object -TypeName OceanStorPortBond -ArgumentList @($source, $script:session)

        $result.'Ethernet Ports' | Should -Be '1211, 1212'
    }

    It 'renders an empty bond PORTIDLIST as an empty string, not a phantom entry' {
        $source = [pscustomobject]@{ ID = 'bond-01'; NAME = 'bond0'; TYPE = 235; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; PORTIDLIST = '[""]' }

        $result = New-Object -TypeName OceanStorPortBond -ArgumentList @($source, $script:session)

        $result.'Ethernet Ports' | Should -BeNullOrEmpty
    }

    It 'maps an Ethernet port' {
        $source = [pscustomobject]@{ ID = 'eth-01'; NAME = 'eth0'; TYPE = 213; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; LOGICTYPE = 0 }

        $result = New-Object -TypeName OceanStorPortETH -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'eth-01'
        $result.Name | Should -Be 'eth0'
        $result.'Running Status' | Should -Be 'link up'
    }

    It 'maps a fibre channel port' {
        $source = [pscustomobject]@{ ID = 'fc-port-01'; NAME = 'fc0'; TYPE = 212; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; PARENTTYPE = 207 }

        $result = New-Object -TypeName OceanStorPortFC -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'fc-port-01'
        $result.Name | Should -Be 'fc0'
        $result.'Port Type' | Should -Be 'Fibre Channel'
    }

    It 'maps a SAS port' {
        $source = [pscustomobject]@{ ID = 'sas-01'; NAME = 'sas0'; TYPE = 214; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; ISMINISAS = $true }

        $result = New-Object -TypeName OceanstorPortSAS -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'sas-01'
        $result.Name | Should -Be 'sas0'
        $result.'Mini SAS' | Should -Be 'yes'
    }

    It 'maps a VLAN interface' {
        $source = [pscustomobject]@{ ID = 'vlan-01'; NAME = 'vlan100'; TYPE = 280; TAG = 100; PORTTYPE = 1; RUNNINGSTATUS = 10 }

        $result = New-Object -TypeName OceanStorvLan -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'vlan-01'
        $result.'Vlan Tag Id' | Should -Be '100'
        $result.'Port Type' | Should -Be 'ETH Port'
    }
}
