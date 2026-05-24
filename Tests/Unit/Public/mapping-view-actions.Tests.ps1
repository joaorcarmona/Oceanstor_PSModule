BeforeDiscovery {
    $script:mappingViewModule = New-Module -Name MappingViewTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function get-DMhostGroups { param([pscustomobject]$WebSession) }
        function get-DMlunGroups { param([pscustomobject]$WebSession) }
        function Get-DMPortGroup { param([pscustomobject]$WebSession) }
        function invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMHostGroupToMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHostGroupFromMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMLunGroupToMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunGroupFromMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMPortGroupToMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMPortGroupFromMappingView.ps1"

        Export-ModuleMember -Function '*-DMMappingView', '*-DMHostGroupToMappingView', '*-DMHostGroupFromMappingView',
            '*-DMLunGroupToMappingView', '*-DMLunGroupFromMappingView', '*-DMPortGroupToMappingView',
            '*-DMPortGroupFromMappingView'
    }

    Import-Module $script:mappingViewModule -Force
}

AfterAll {
    Remove-Module -Name MappingViewTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope MappingViewTestModule {
Describe 'Mapping view commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:viewData = [pscustomobject]@{
            ID = 'mv-01'; NAME = 'application'; DESCRIPTION = 'database access'; TYPE = 245
            HEALTHSTATUS = '1'; RUNNINGSTATUS = '27'; HOSTGROUPID = 'hg-01'
            LUNGROUPID = 'lg-01'; PORTGROUPID = 'pg-01'; vstoreId = '7'; vstoreName = 'tenant-a'
        }
        $script:view = [OceanStorMappingView]::new($script:viewData, $script:session)
        Mock get-DMhostGroups { @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' }) }
        Mock get-DMlunGroups { @([pscustomobject]@{ Id = 'lg-01'; Name = 'production' }) }
        Mock Get-DMPortGroup { @([pscustomobject]@{ Id = 'pg-01'; Name = 'front-end' }) }
    }

    It 'creates a mapping view and returns a typed object' {
        Mock invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $script:viewData }
        }

        $result = New-DMMappingView -WebSession $script:session -Name 'application' -Description 'database access' -VstoreId '7'

        $result.GetType().Name | Should -Be 'OceanStorMappingView'
        $result.Name | Should -Be 'application'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'mappingview'
        $script:request.TYPE | Should -Be 245
        $script:request.DESCRIPTION | Should -Be 'database access'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'queries associated mapping views for a host group' {
        Mock invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ data = @($script:viewData) }
        }

        $result = @(Get-DMMappingView -WebSession $script:session -HostGroupName 'cluster01' -VstoreId '7')

        $result[0].GetType().Name | Should -Be 'OceanStorMappingView'
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=hg-01&vstoreId=7'
    }

    It 'queries associated mapping views for LUN and port groups with their REST object types' {
        Mock invoke-DeviceManager {
            $script:resources += $Resource
            [pscustomobject]@{ data = @($script:viewData) }
        }
        $script:resources = @()

        $null = Get-DMMappingView -WebSession $script:session -LunGroupName 'production'
        $null = Get-DMMappingView -WebSession $script:session -PortGroupName 'front-end'

        $script:resources | Should -Contain 'mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=256&ASSOCIATEOBJID=lg-01'
        $script:resources | Should -Contain 'mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=257&ASSOCIATEOBJID=pg-01'
    }

    It 'removes a resolved mapping view by ID' {
        Mock Get-DMMappingView { @($script:view) }
        Mock invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $result = Remove-DMMappingView -WebSession $script:session -MappingViewName 'application' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'mappingview/mv-01?vstoreId=7'
    }
}

Describe 'Mapping view association commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:view = [OceanStorMappingView]::new([pscustomobject]@{ ID = 'mv-01'; NAME = 'application' }, $script:session)
        Mock Get-DMMappingView { @($script:view) }
        Mock get-DMhostGroups { @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' }) }
        Mock get-DMlunGroups { @([pscustomobject]@{ Id = 'lg-01'; Name = 'production' }) }
        Mock Get-DMPortGroup { @([pscustomobject]@{ Id = 'pg-01'; Name = 'front-end' }) }
        Mock invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'adds a host group to a mapping view' {
        $result = Add-DMHostGroupToMappingView -WebSession $script:session -MappingViewName 'application' -HostGroupName 'cluster01' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'mappingview/CREATE_ASSOCIATE'
        $script:request.ID | Should -Be 'mv-01'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 14
        $script:request.ASSOCIATEOBJID | Should -Be 'hg-01'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'adds LUN and port groups with their mapping REST object types' {
        $null = Add-DMLunGroupToMappingView -WebSession $script:session -MappingViewName 'application' -LunGroupName 'production' -Confirm:$false
        $script:request.ASSOCIATEOBJTYPE | Should -Be 256
        $script:request.ASSOCIATEOBJID | Should -Be 'lg-01'

        $null = Add-DMPortGroupToMappingView -WebSession $script:session -MappingViewName 'application' -PortGroupName 'front-end' -Confirm:$false
        $script:request.ASSOCIATEOBJTYPE | Should -Be 257
        $script:request.ASSOCIATEOBJID | Should -Be 'pg-01'
    }

    It 'removes each verified group association through the modification interface' {
        $null = Remove-DMHostGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -HostGroupName 'cluster01' -Confirm:$false
        $script:resource | Should -Be 'mappingview/REMOVE_ASSOCIATE'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 14

        $null = Remove-DMLunGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -LunGroupName 'production' -Confirm:$false
        $script:request.ASSOCIATEOBJTYPE | Should -Be 256

        $null = Remove-DMPortGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -PortGroupName 'front-end' -Confirm:$false
        $script:request.ASSOCIATEOBJTYPE | Should -Be 257
    }

    It 'rejects removal when the group is not associated with the mapping view' {
        Mock Get-DMMappingView {
            if ($PortGroupName) { return @() }
            return @($script:view)
        }

        { Remove-DMPortGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -PortGroupName 'front-end' -Confirm:$false } |
            Should -Throw '*not associated*'

        Should -Invoke invoke-DeviceManager -Times 0 -Exactly
    }

    It 'honors WhatIf for association creation' {
        $null = Add-DMLunGroupToMappingView -WebSession $script:session -MappingViewName 'application' -LunGroupName 'production' -WhatIf

        Should -Invoke invoke-DeviceManager -Times 0 -Exactly
    }
}
}
