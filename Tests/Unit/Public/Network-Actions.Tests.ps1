BeforeDiscovery {
    $script:networkActionsModule = New-Module -Name NetworkActionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [object]$BodyData
            )

            $script:lastRequest = [pscustomobject]@{
                WebSession = $WebSession
                Method     = $Method
                Resource   = $Resource
                BodyData   = $BodyData
            }

            [pscustomobject]@{
                data  = [pscustomobject]@{ ID = 'created-01'; NAME = 'created'; TYPE = 235 }
                error = [pscustomobject]@{ Code = 0; description = '0' }
            }
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\New-DMRequestBody.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorFailoverGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLIF.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPortBond.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorvlLan.ps1"

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMFailoverGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMFailoverGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMFailoverGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMFailoverGroupMember.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMFailoverGroupMember.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMLif.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMLif.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLif.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMPortBond.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMPortBond.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMPortBond.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMvLan.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMvLan.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMvLan.ps1"

        Export-ModuleMember -Function '*-DM*' -Alias '*'
    }

    Import-Module $script:networkActionsModule -Force
}

AfterAll {
    Remove-Module -Name NetworkActionsTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NetworkActionsTestModule {
    Describe 'Network mutation cmdlets' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array.example'; DeviceId = 'dev-01' }
            $script:lastRequest = $null
        }

        It 'creates bond ports' {
            New-DMPortBond -WebSession $script:session -Name 'bond0' -PortIdList 'eth-01', 'eth-02' -BondPortType 1

            $script:lastRequest.Method | Should -Be 'POST'
            $script:lastRequest.Resource | Should -Be 'bond_port'
            $script:lastRequest.BodyData.NAME | Should -Be 'bond0'
            $script:lastRequest.BodyData.PORTIDLIST | Should -Be @('eth-01', 'eth-02')
            $script:lastRequest.BodyData.bondPortType | Should -Be 1
        }

        It 'modifies bond ports by id' {
            Set-DMPortBond -WebSession $script:session -Id 'bond-01' -Mtu 1502 -IPv4Address '192.0.2.10' -Confirm:$false

            $script:lastRequest.Method | Should -Be 'PUT'
            $script:lastRequest.Resource | Should -Be 'bond_port/bond-01'
            $script:lastRequest.BodyData.ID | Should -Be 'bond-01'
            $script:lastRequest.BodyData.MTU | Should -Be 1502
            $script:lastRequest.BodyData.IPV4ADDR | Should -Be '192.0.2.10'
        }

        It 'removes bond ports by name through the delete alias' {
            Delete-DMPortBond -WebSession $script:session -Name 'bond0' -Confirm:$false

            $script:lastRequest.Method | Should -Be 'DELETE'
            $script:lastRequest.Resource | Should -Be 'bond_port'
            $script:lastRequest.BodyData.NAME | Should -Be 'bond0'
        }

        It 'creates VLAN ports' {
            New-DMvLan -WebSession $script:session -Tag 123 -PortType 1 -PortId 'eth-01'

            $script:lastRequest.Method | Should -Be 'POST'
            $script:lastRequest.Resource | Should -Be 'vlan'
            $script:lastRequest.BodyData.TAG | Should -Be 123
            $script:lastRequest.BodyData.PORTTYPE | Should -Be 1
            $script:lastRequest.BodyData.PORTID | Should -Be 'eth-01'
        }

        It 'modifies VLAN MTU' {
            Set-DMvLan -WebSession $script:session -Id 'vlan-01' -Mtu 1502 -Confirm:$false

            $script:lastRequest.Method | Should -Be 'PUT'
            $script:lastRequest.Resource | Should -Be 'vlan/vlan-01'
            $script:lastRequest.BodyData.MTU | Should -Be 1502
        }

        It 'removes VLAN ports through the delete alias' {
            Delete-DMvLan -WebSession $script:session -Id 'vlan-01' -Confirm:$false

            $script:lastRequest.Method | Should -Be 'DELETE'
            $script:lastRequest.Resource | Should -Be 'vlan/vlan-01'
        }

        It 'creates logical interfaces' {
            New-DMLif -WebSession $script:session -Name 'lif01' -AddressFamily 0 -IPv4Address '192.0.2.20' -IPv4Mask '255.255.255.0' -HomePortType 1 -HomePortName 'CTE0.A.IOM1.P0' -SupportProtocol 4

            $script:lastRequest.Method | Should -Be 'POST'
            $script:lastRequest.Resource | Should -Be 'lif'
            $script:lastRequest.BodyData.NAME | Should -Be 'lif01'
            $script:lastRequest.BodyData.ADDRESSFAMILY | Should -Be 0
            $script:lastRequest.BodyData.IPV4ADDR | Should -Be '192.0.2.20'
            $script:lastRequest.BodyData.HOMEPORTTYPE | Should -Be 1
            $script:lastRequest.BodyData.HOMEPORTNAME | Should -Be 'CTE0.A.IOM1.P0'
        }

        It 'modifies logical interfaces' {
            Set-DMLif -WebSession $script:session -Name 'lif01' -AddressFamily 1 -IPv6Address '2001:db8::1' -IPv6Mask '64' -Confirm:$false

            $script:lastRequest.Method | Should -Be 'PUT'
            $script:lastRequest.Resource | Should -Be 'lif'
            $script:lastRequest.BodyData.NAME | Should -Be 'lif01'
            $script:lastRequest.BodyData.ADDRESSFAMILY | Should -Be 1
            $script:lastRequest.BodyData.IPV6ADDR | Should -Be '2001:db8::1'
            $script:lastRequest.BodyData.IPV6MASK | Should -Be '64'
        }

        It 'removes logical interfaces through the delete alias' {
            Delete-DMLif -WebSession $script:session -Name 'lif01' -VstoreId '0' -Confirm:$false

            $script:lastRequest.Method | Should -Be 'DELETE'
            $script:lastRequest.Resource | Should -Be 'lif'
            $script:lastRequest.BodyData.NAME | Should -Be 'lif01'
            $script:lastRequest.BodyData.vstoreId | Should -Be '0'
        }

        It 'creates failover groups' {
            New-DMFailoverGroup -WebSession $script:session -Name 'fg01' -Description 'front-end' -FailoverGroupServiceType 0

            $script:lastRequest.Method | Should -Be 'POST'
            $script:lastRequest.Resource | Should -Be 'failovergroup'
            $script:lastRequest.BodyData.NAME | Should -Be 'fg01'
            $script:lastRequest.BodyData.DESCRIPTION | Should -Be 'front-end'
            $script:lastRequest.BodyData.FAILOVERGROUPTYPE | Should -Be 3
            $script:lastRequest.BodyData.failoverGroupServiceType | Should -Be 0
        }

        It 'modifies failover groups' {
            Set-DMFailoverGroup -WebSession $script:session -Id 'fg-01' -Description 'updated' -Confirm:$false

            $script:lastRequest.Method | Should -Be 'PUT'
            $script:lastRequest.Resource | Should -Be 'failovergroup/fg-01'
            $script:lastRequest.BodyData.DESCRIPTION | Should -Be 'updated'
        }

        It 'removes failover groups through the delete alias' {
            Delete-DMFailoverGroup -WebSession $script:session -Id 'fg-01' -Confirm:$false

            $script:lastRequest.Method | Should -Be 'DELETE'
            $script:lastRequest.Resource | Should -Be 'failovergroup/fg-01'
        }

        It 'adds failover group members' {
            Add-DMFailoverGroupMember -WebSession $script:session -Id 'fg-01' -AssociateObjectType 213 -AssociateObjectId 'eth-01'

            $script:lastRequest.Method | Should -Be 'POST'
            $script:lastRequest.Resource | Should -Be 'failovergroup/associate'
            $script:lastRequest.BodyData.ID | Should -Be 'fg-01'
            $script:lastRequest.BodyData.ASSOCIATEOBJTYPE | Should -Be 213
            $script:lastRequest.BodyData.ASSOCIATEOBJID | Should -Be 'eth-01'
        }

        It 'removes failover group members through the delete alias' {
            Delete-DMFailoverGroupMember -WebSession $script:session -Id 'fg-01' -AssociateObjectType 213 -AssociateObjectId 'eth-01' -Confirm:$false

            $script:lastRequest.Method | Should -Be 'DELETE'
            $script:lastRequest.Resource | Should -Be 'failovergroup/associate?ID=fg-01&ASSOCIATEOBJTYPE=213&ASSOCIATEOBJID=eth-01'
        }
    }
}
