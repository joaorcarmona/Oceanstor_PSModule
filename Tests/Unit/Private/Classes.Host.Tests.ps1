BeforeAll {
    function global:Get-DMHostLink {}

    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHost.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHostGroup.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHostLink.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHostinitiatorFC.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHostinitiatorISCSI.ps1"
}

AfterAll {
    Remove-Item function:global:Get-DMHostLink -ErrorAction SilentlyContinue
    Remove-Variable -Name HostPathsCall -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Host model classes' {
    BeforeAll {
        $script:session = [pscustomobject]@{ Name = 'Test-session' }
    }

    It 'maps a host and its operating system' {
        $source = [pscustomobject]@{ ID = 'host-01'; NAME = 'server01'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; OPERATIONSYSTEM = 7; TYPE = 21 }

        $result = New-Object -TypeName OceanStorHost -ArgumentList @($source, $script:session)

        $result.id | Should -Be 'host-01'
        $result.'Operation System' | Should -Be 'VMware ESX'
        $result.type | Should -Be 'Host'
        $result.initiators = @('fc-01', 'iscsi-01')
        $result.initiators | Should -Be @('fc-01', 'iscsi-01')
        $result.Session | Should -Be $script:session
    }

    It 'retrieves all supported path types from a host object' {
        function global:Get-DMHostLink {
            param($WebSession, $HostId, $InitiatorType)
            $global:HostPathsCall += [pscustomobject]@{
                Session = $WebSession
                HostId = $HostId
                InitiatorType = $InitiatorType
            }
            [pscustomobject]@{ Id = "$HostId-$InitiatorType" }
        }

        $global:HostPathsCall = @()
        $hostObject = [OceanStorHost]::new([pscustomobject]@{ ID = 'host-01'; NAME = 'server01' }, $script:session)

        $result = @($hostObject.GetHostPaths())

        $result.Id | Should -Be @('host-01-FC', 'host-01-ISCSI', 'host-01-Infiniband')
        $global:HostPathsCall.HostId | Should -Be @('host-01', 'host-01', 'host-01')
        $global:HostPathsCall.InitiatorType | Should -Be @('FC', 'ISCSI', 'Infiniband')
        $global:HostPathsCall.Session | Should -Be @($script:session, $script:session, $script:session)
    }

    It 'maps host group identity and mapping state' {
        $source = [pscustomobject]@{ ID = 4; NAME = 'cluster'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }

        $result = New-Object -TypeName OceanStorHostGroup -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 4
        $result.Name | Should -Be 'cluster'
        $result.'Is Mapped' | Should -BeTrue
    }

    It 'maps an active host link' {
        $source = [pscustomobject]@{ ID = 'link-01'; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; TARGET_TYPE = 212; TYPE = 255 }

        $result = New-Object -TypeName OceanStorHostLink -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'link-01'
        $result.'Running Status' | Should -Be 'Link UP'
        $result.'Target Type' | Should -Be 'Fibre Channel Port'
    }

    It 'maps a fibre channel initiator' {
        $source = [pscustomobject]@{ ID = 'fc-01'; TYPE = 223; PARENTTYPE = 21; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; OPERATIONSYSTEM = 0; vstoreid = 4294967295 }

        $result = New-Object -TypeName OceanstorHostinitiatorFC -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'fc-01'
        $result.Type | Should -Be 'FC Initiator'
        $result.'Operating System' | Should -Be 'Linux'
        $result.'vStore ID' | Should -Be 4294967295
    }

    It 'maps an iSCSI initiator and CHAP state' {
        $source = [pscustomobject]@{ ID = 'iscsi-01'; TYPE = 222; PARENTTYPE = 21; USECHAP = $true; CHAPNAME = 'chap-user'; RUNNINGSTATUS = 27; vstoreid = 4294967295 }

        $result = New-Object -TypeName OceanstorHostinitiatorISCSI -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'iscsi-01'
        $result.Type | Should -Be 'ISCSI Initiator'
        $result.'Use CHAP' | Should -BeTrue
        $result.'vStore ID' | Should -Be 4294967295
    }
}
