BeforeDiscovery {
    $script:guardModule = New-Module -Name VlanGuardTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMVlanParentPortStatus.ps1"

        Export-ModuleMember -Function 'Get-*'
    }

    Import-Module $script:guardModule -Force
}

AfterAll {
    Remove-Module -Name VlanGuardTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope VlanGuardTestModule {
    Describe 'Get-DMVlanParentPortStatus idle-port guard' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001' }
            # Default: every association endpoint is empty (idle port).
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }
        }

        It 'reports Idle when the port has no associations' {
            $result = Get-DMVlanParentPortStatus -WebSession $script:session -PortId 'eth-99'

            $result.PortId | Should -Be 'eth-99'
            $result.Status | Should -Be 'Idle'
            $result.IsIdle | Should -BeTrue
            $result.Reasons | Should -BeNullOrEmpty
            $result.CheckedAssociations | Should -Contain 'Lif'
            $result.CheckedAssociations | Should -Contain 'Vlan'
            $result.CheckedAssociations | Should -Contain 'Bond'
            $result.CheckedAssociations | Should -Contain 'FailoverGroup'
        }

        It 'reports InUse when a LIF is homed on the port' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01'; NAME = 'nas_lif1'; HOMEPORTID = 'eth-01' }) }
            } -ParameterFilter { $Resource -like 'lif*' }

            $result = Get-DMVlanParentPortStatus -WebSession $script:session -PortId 'eth-01'

            $result.Status | Should -Be 'InUse'
            $result.IsIdle | Should -BeFalse
            ($result.Reasons -join ' ') | Should -Match 'LIF'
        }

        It 'reports InUse when a VLAN is parented on the port' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'vlan-05'; TYPE = 280; TAG = 100; PORTID = 'eth-01' }) }
            } -ParameterFilter { $Resource -eq 'vlan' }

            $result = Get-DMVlanParentPortStatus -WebSession $script:session -PortId 'eth-01'

            $result.Status | Should -Be 'InUse'
            $result.IsIdle | Should -BeFalse
            ($result.Reasons -join ' ') | Should -Match 'VLAN'
        }

        It 'reports InUse when the port is a bond member' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'bond-01'; NAME = 'bond0'; TYPE = 235; PORTIDLIST = '["eth-01","eth-02"]' }) }
            } -ParameterFilter { $Resource -eq 'bond_port' }

            $result = Get-DMVlanParentPortStatus -WebSession $script:session -PortId 'eth-01'

            $result.Status | Should -Be 'InUse'
            $result.IsIdle | Should -BeFalse
            ($result.Reasons -join ' ') | Should -Match 'bond'
        }

        It 'reports InUse when the port is a failover-group member' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fg-01'; NAME = 'fg01'; TYPE = 289; FAILOVERGROUPTYPE = 3 }) }
            } -ParameterFilter { $Resource -like 'failovergroup*' }
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'eth-01'; NAME = 'CTE0.A.IOM1.P0'; TYPE = 213; RUNNINGSTATUS = 10 }) }
            } -ParameterFilter { $Resource -like 'eth_port/associate*' }

            $result = Get-DMVlanParentPortStatus -WebSession $script:session -PortId 'eth-01'

            $result.Status | Should -Be 'InUse'
            $result.IsIdle | Should -BeFalse
            ($result.Reasons -join ' ') | Should -Match 'failover'
        }

        It 'reports Unknown (unsafe) when an association check errors' {
            Mock Invoke-DeviceManager { throw 'REST unavailable' } -ParameterFilter { $Resource -like 'lif*' }

            $result = Get-DMVlanParentPortStatus -WebSession $script:session -PortId 'eth-01'

            $result.Status | Should -Be 'Unknown'
            $result.IsIdle | Should -BeFalse
            ($result.Reasons -join ' ') | Should -Match 'failed'
        }

        It 'never issues a mutating REST call' {
            $null = Get-DMVlanParentPortStatus -WebSession $script:session -PortId 'eth-01'

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter {
                $Method -in @('PUT', 'POST', 'DELETE')
            }
        }
    }
}
