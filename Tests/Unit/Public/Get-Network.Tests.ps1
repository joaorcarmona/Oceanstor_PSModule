BeforeDiscovery {
    $script:getNetworkModule = New-Module -Name GetNetworkTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiators.ps1"

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Private" -Filter 'class-*.ps1' |
            Where-Object Name -ne 'class-OceanStorMappingView.ps1' |
            ForEach-Object { . $_.FullName }

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Public" -Filter 'Get-*.ps1' |
            ForEach-Object { . $_.FullName }

        Export-ModuleMember -Function 'Get-*'
    }

    Import-Module $script:getNetworkModule -Force
}

AfterAll {
    Remove-Module -Name GetNetworkTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope GetNetworkTestModule {
Describe 'Public getter functions' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }
    }
    Describe 'Network getter functions' {
        It 'gets DNS servers' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = [pscustomobject]@{ ADDRESS = '["10.0.0.1","10.0.0.2"]' } } }

            $result = Get-DMdnsServer -WebSession $script:session

            $result['DNS Server 1'] | Should -Be '10.0.0.1'
            $result['DNS Server 2'] | Should -Be '10.0.0.2'
        }

        It 'gets logical interfaces' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01'; ADDRESSFAMILY = 0; SUPPORTPROTOCOL = 3 }) } }

            $result = (Get-DMLif -WebSession $script:session)[0]

            $result.Id | Should -Be 'lif-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'LIF Name', 'IPv4 Address', 'Running Status', 'Support Protocol')
            $result.'Address Family' | Should -Be 'IPv4'
        }

        It 'gets bond ports' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'bond-01'; NAME = 'bond0'; TYPE = 235 }) } }

            $result = (Get-DMPortBond -WebSession $script:session)[0]

            $result.Id | Should -Be 'bond-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Ethernet Ports')
            $result.'Port Type' | Should -Be 'Bond Port'
        }

        It 'gets Ethernet ports' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'eth-01'; NAME = 'eth0'; TYPE = 213 }) } }

            $result = (Get-DMPortETH -WebSession $script:session)[0]

            $result.Id | Should -Be 'eth-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'IPv4 Address')
            $result.'Port Type' | Should -Be 'Ethernet Port'
        }

        It 'gets fibre channel ports' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fc-01'; NAME = 'fc0'; TYPE = 212 }) } }

            $result = (Get-DMPortFc -WebSession $script:session)[0]

            $result.Id | Should -Be 'fc-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'WWN')
            $result.'Port Type' | Should -Be 'Fibre Channel'
        }

        It 'gets SAS ports' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'sas-01'; NAME = 'sas0'; TYPE = 214 }) } }

            $result = (Get-DMPortSAS -WebSession $script:session)[0]

            $result.Id | Should -Be 'sas-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Port Location')
            $result.'Port Type' | Should -Be 'SAS Port'
        }

        It 'gets VLAN interfaces' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'vlan-01'; TYPE = 280; TAG = 100 }) } }

            $result = (Get-DMvLan -WebSession $script:session)[0]

            $result.Id | Should -Be 'vlan-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Vlan Tag Id', 'Port Type', 'Running Status')
            $result.Type | Should -Be 'VLAN'
        }
    }
}
}
