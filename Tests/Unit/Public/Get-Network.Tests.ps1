BeforeDiscovery {
    $script:getNetworkModule = New-Module -Name GetNetworkTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [object]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Private" -Filter 'class-*.ps1' |
            Where-Object Name -notin 'class-OceanStorMappingView.ps1', 'class-OceanstorSession.ps1' |
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

            $result = @(Get-DMdnsServer -WebSession $script:session)

            $result[0].Address | Should -Be '10.0.0.1'
            $result[1].Address | Should -Be '10.0.0.2'
        }

        It 'gets a single configured DNS server' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = [pscustomobject]@{ ADDRESS = '["8.8.8.8"]' } } }

            $result = @(Get-DMdnsServer -WebSession $script:session)

            $result.Count | Should -Be 1
            $result[0].Address | Should -Be '8.8.8.8'
        }

        It 'returns an empty table when no DNS servers are configured' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = [pscustomobject]@{ ADDRESS = '[]' } } }

            $result = Get-DMdnsServer -WebSession $script:session

            $result.Count | Should -Be 0
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

        It 'filters logical interfaces server-side with an exact NAME filter' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01'; NAME = 'nas_lif1'; ADDRESSFAMILY = 0 }) } }

            $result = @(Get-DMLif -WebSession $script:session -Name 'nas_lif1')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Resource -eq 'lif?filter=NAME%3A%3Anas_lif1' -or $Resource -eq 'lif?filter=NAME::nas_lif1'
            }
            $result.Count | Should -Be 1
        }

        It 'sends a fuzzy NAME filter and re-checks client-side for wildcard LIF lookups' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @(
                [pscustomobject]@{ ID = 'lif-01'; NAME = 'nas_lif1' },
                [pscustomobject]@{ ID = 'lif-02'; NAME = 'other_nas_lif' }
            ) } }

            $result = @(Get-DMLif -WebSession $script:session -Name 'nas_lif*')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -like 'lif?filter=NAME:*' -and $Resource -notlike 'lif?filter=NAME::*' }
            $result.Count | Should -Be 1
            $result[0].'LIF Name' | Should -Be 'nas_lif1'
        }

        It 'gets a logical interface by id through the documented single-object query' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = [pscustomobject]@{ ID = 'lif-01'; NAME = 'nas_lif1' } } }

            $result = @(Get-DMLif -WebSession $script:session -Id 'lif-01')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lif/lif-01' }
            $result[0].Id | Should -Be 'lif-01'
        }

        It 'still lists all logical interfaces without a filter' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01' }, [pscustomobject]@{ ID = 'lif-02' }) } }

            $result = @(Get-DMLif -WebSession $script:session)

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lif' }
            $result.Count | Should -Be 2
        }

        It 'filters logical interfaces server-side by IPV4ADDR' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01' }) } }

            $null = @(Get-DMLif -WebSession $script:session -Ipv4Addr '10.0.0.5')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Resource -eq 'lif?filter=IPV4ADDR::10.0.0.5' -or $Resource -eq 'lif?filter=IPV4ADDR%3A%3A10.0.0.5'
            }
        }

        It 'filters logical interfaces server-side by IPV6ADDR' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01' }) } }

            $null = @(Get-DMLif -WebSession $script:session -Ipv6Addr 'fe80::1')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Resource -like 'lif?filter=IPV6ADDR*fe80*'
            }
        }

        It 'filters logical interfaces server-side by HOMEPORTID' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01' }) } }

            $null = @(Get-DMLif -WebSession $script:session -HomePortId 'eth-01')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Resource -eq 'lif?filter=HOMEPORTID::eth-01' -or $Resource -eq 'lif?filter=HOMEPORTID%3A%3Aeth-01'
            }
        }

        It 'composes LIF NAME and HOMEPORTID filters with an AND clause' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01'; NAME = 'nas_lif1' }) } }

            $null = @(Get-DMLif -WebSession $script:session -Name 'nas_lif1' -HomePortId 'eth-01')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Resource -match 'NAME(::|%3A%3A)nas_lif1' -and
                $Resource -match 'HOMEPORTID(::|%3A%3A)eth-01' -and
                $Resource -match '\?filter=' -and
                $Resource -match ' and '
            }
        }

        It 'filters VLANs server-side with an exact NAME filter' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'vlan-01'; NAME = 'CTE0.A.100'; TYPE = 280; TAG = 100 }) } }

            $result = @(Get-DMvLan -WebSession $script:session -Name 'CTE0.A.100')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -like 'vlan?filter=NAME*' }
            $result.Count | Should -Be 1
        }

        It 'filters VLANs server-side by TAG' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'vlan-01'; TYPE = 280; TAG = 100 }) } }

            $null = @(Get-DMvLan -WebSession $script:session -Tag '100')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Resource -eq 'vlan?filter=TAG::100' -or $Resource -eq 'vlan?filter=TAG%3A%3A100'
            }
        }

        It 'filters VLANs server-side by fatherDrvType' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'vlan-01'; TYPE = 280 }) } }

            $null = @(Get-DMvLan -WebSession $script:session -FatherDrvType '1')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Resource -eq 'vlan?filter=fatherDrvType::1' -or $Resource -eq 'vlan?filter=fatherDrvType%3A%3A1'
            }
        }

        It 'composes VLAN TAG and fatherDrvType filters with an AND clause' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'vlan-01'; TYPE = 280; TAG = 100 }) } }

            $null = @(Get-DMvLan -WebSession $script:session -Tag '100' -FatherDrvType '1')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Resource -match 'TAG(::|%3A%3A)100' -and
                $Resource -match 'fatherDrvType(::|%3A%3A)1' -and
                $Resource -match ' and '
            }
        }

        It 'gets a VLAN by id through the documented single-object query' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = [pscustomobject]@{ ID = 'vlan-01'; TYPE = 280; TAG = 100 } } }

            $result = @(Get-DMvLan -WebSession $script:session -Id 'vlan-01')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'vlan/vlan-01' }
            $result[0].Id | Should -Be 'vlan-01'
        }

        It 'gets failover group members from the three documented association queries' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'eth-01'; NAME = 'CTE0.A.IOM1.P0'; TYPE = 213; RUNNINGSTATUS = 10 }) } } -ParameterFilter { $Resource -like 'eth_port/associate*' }
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'bond-01'; NAME = 'bond0'; TYPE = 235; RUNNINGSTATUS = 11 }) } } -ParameterFilter { $Resource -like 'bond_port/associate*' }
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } } -ParameterFilter { $Resource -like 'vlan/associate*' }

            $result = @(Get-DMFailoverGroupMember -WebSession $script:session -Id 'fg-01')

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'eth_port/associate?ASSOCIATEOBJTYPE=289&ASSOCIATEOBJID=fg-01' }
            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'bond_port/associate?ASSOCIATEOBJTYPE=289&ASSOCIATEOBJID=fg-01' }
            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'vlan/associate?ASSOCIATEOBJTYPE=289&ASSOCIATEOBJID=fg-01' }
            $result.Count | Should -Be 2
            $result[0].'Member Type' | Should -Be 'Ethernet Port'
            $result[0].'Running Status' | Should -Be 'Link Up'
            $result[0].'Failover Group Id' | Should -Be 'fg-01'
            $result[1].'Member Type' | Should -Be 'Bond Port'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Member Type', 'Running Status', 'Failover Group Id')
        }

        It 'narrows failover group member queries with -MemberType' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }

            $null = Get-DMFailoverGroupMember -WebSession $script:session -Id 'fg-01' -MemberType 280

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'vlan/associate?ASSOCIATEOBJTYPE=289&ASSOCIATEOBJID=fg-01' }
        }

        It 'returns an empty result for a failover group with no members' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }

            $result = Get-DMFailoverGroupMember -WebSession $script:session -Id 'fg-01'

            @($result).Count | Should -Be 0
        }

        It 'accepts a failover group from the pipeline for member lookup' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }

            $group = [pscustomobject]@{ Id = 'fg-07' }
            $null = $group | Get-DMFailoverGroupMember -WebSession $script:session

            Should -Invoke Invoke-DeviceManager -Times 3 -Exactly -ParameterFilter { $Resource -like '*ASSOCIATEOBJID=fg-07' }
        }

        It 'gets failover groups' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fg-01'; NAME = 'fg01'; TYPE = 289; FAILOVERGROUPTYPE = 3; failoverGroupServiceType = 0 }) } }

            $result = (Get-DMFailoverGroup -WebSession $script:session)[0]

            $result.Id | Should -Be 'fg-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Failover Group Type', 'Description', 'Service Type')
            $result.Type | Should -Be 'Failover Group'
            $result.'Failover Group Type' | Should -Be 'Customized'
        }
    }
}
}
