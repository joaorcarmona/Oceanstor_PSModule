BeforeDiscovery {
    $script:portGroupModule = New-Module -Name PortGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPortFc { param([pscustomobject]$WebSession) }
        function Get-DMPortETH { param([pscustomobject]$WebSession) }
        function Get-DMLif { param([pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPortGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMPortGroupCandidate.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMPortGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPortGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMPortGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMPortToPortGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMPortFromPortGroup.ps1"

        Export-ModuleMember -Function '*-DMPortGroup', '*-DMPortToPortGroup', '*-DMPortFromPortGroup'
    }

    Import-Module $script:portGroupModule -Force
}

AfterAll {
    Remove-Module -Name PortGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope PortGroupTestModule {
Describe 'Port group commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:groupData = [pscustomobject]@{
            ID = 'pg-01'; NAME = 'front-end'; DESCRIPTION = 'host paths'; TYPE = 257
            isAddToMappingView = 'false'; portNum = '1'; portType = '0'; vstoreId = '7'; vstoreName = 'tenant-a'
        }
        $script:group = [OceanstorPortGroup]::new($script:groupData, $script:session)
        Mock Get-DMPortFc { @([pscustomobject]@{ Id = 'fc-01'; Name = 'CTE0.A.IOM0.P0' }) }
        Mock Get-DMPortETH { @([pscustomobject]@{ Id = 'eth-01'; Name = 'CTE0.A.IOM1.P0' }) }
        Mock Get-DMLif { @([pscustomobject]@{ Id = 'lif-01'; 'LIF Name' = 'service01' }) }
    }

    It 'creates a port group and returns a typed object' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $script:groupData }
        }

        $result = New-DMPortGroup -WebSession $script:session -Name 'front-end' -Description 'host paths'

        $result.GetType().Name | Should -Be 'OceanstorPortGroup'
        $result.Name | Should -Be 'front-end'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'portgroup'
        $script:request.NAME | Should -Be 'front-end'
        $script:request.DESCRIPTION | Should -Be 'host paths'
        $script:request.ContainsKey('vstoreId') | Should -BeFalse
    }

    It 'queries port groups into typed objects for a vStore' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ data = @($script:groupData) }
        }

        $result = @(Get-DMPortGroup -WebSession $script:session -VstoreId '7')

        $result[0].GetType().Name | Should -Be 'OceanstorPortGroup'
        $result[0].'Port Type' | Should -Be 'Physical Port'
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'portgroup?vstoreId=7'
    }

    It 'removes a resolved port group by ID' {
        Mock Get-DMPortGroup { @($script:group) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $result = Remove-DMPortGroup -WebSession $script:session -PortGroupName 'front-end' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'portgroup/pg-01?vstoreId=7'
    }
}

Describe 'Port group membership commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:group = [OceanstorPortGroup]::new([pscustomobject]@{
            ID = 'pg-01'; NAME = 'front-end'; isAddToMappingView = 'false'; portNum = '1'; portType = '0'
        }, $script:session)
        Mock Get-DMPortGroup { @($script:group) }
        Mock Get-DMPortFc { @([pscustomobject]@{ Id = 'fc-01'; Name = 'CTE0.A.IOM0.P0' }) }
        Mock Get-DMPortETH { @([pscustomobject]@{ Id = 'eth-01'; Name = 'CTE0.A.IOM1.P0' }) }
        Mock Get-DMLif { @([pscustomobject]@{ Id = 'lif-01'; 'LIF Name' = 'service01' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'adds a resolved Fibre Channel port with its REST object type' {
        $result = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'port/associate/portgroup'
        $script:request.ID | Should -Be 'pg-01'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 212
        $script:request.ASSOCIATEOBJID | Should -Be 'fc-01'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'adds a logical port using the LIF name and logical-port type' {
        $null = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'front-end' -PortType LogicalPort -PortName 'service01' -Confirm:$false

        $script:request.ASSOCIATEOBJTYPE | Should -Be 279
        $script:request.ASSOCIATEOBJID | Should -Be 'lif-01'
    }

    It 'removes a port only after confirming its port-group association' {
        Mock Invoke-DeviceManager {
            if ($Method -eq 'GET') {
                $script:associationResource = $Resource
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'pg-01'; NAME = 'front-end' }) }
            }

            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $result = Remove-DMPortFromPortGroup -WebSession $script:session -PortGroupName 'front-end' -PortType Ethernet -PortName 'CTE0.A.IOM1.P0' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:associationResource | Should -Be 'portgroup/associate?ASSOCIATEOBJTYPE=213&ASSOCIATEOBJID=eth-01&vstoreId=7'
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'port/associate/portgroup'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 213
        $script:request.ASSOCIATEOBJID | Should -Be 'eth-01'
    }

    It 'rejects removal if the port is not associated with the requested group' {
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'other' }) } }

        { Remove-DMPortFromPortGroup -WebSession $script:session -PortGroupName 'front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -Confirm:$false } |
            Should -Throw '*not a member*'

        Should -Invoke Invoke-DeviceManager -ParameterFilter { $Method -eq 'DELETE' } -Times 0 -Exactly
    }

    It 'honors WhatIf for association creation' {
        $null = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
