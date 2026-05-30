BeforeDiscovery {
    $script:groupMembershipModule = New-Module -Name GroupMembershipTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMhosts { param([pscustomobject]$WebSession) }
        function Get-DMhostGroups { param([pscustomobject]$WebSession) }
        function Get-DMhostsbyHostGroupId { param([pscustomobject]$WebSession, [string]$HostGroupId) }
        function Get-DMluns { param([pscustomobject]$WebSession) }
        function Get-DMlunGroups { param([pscustomobject]$WebSession) }
        function Get-DMlunsbyLunGroup { param([pscustomobject]$WebSession, [psobject]$LunGroup) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMHostToHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHostFromHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMLunToLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunFromLunGroup.ps1"

        Export-ModuleMember -Function 'Add-DMHostToHostGroup', 'Remove-DMHostFromHostGroup', 'Add-DMLunToLunGroup', 'Remove-DMLunFromLunGroup'
    }

    Import-Module $script:groupMembershipModule -Force
}

AfterAll {
    Remove-Module -Name GroupMembershipTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GroupMembershipTestModule {
Describe 'Host group membership commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMhosts { @([pscustomobject]@{ Id = 'host-01'; Name = 'server01' }) }
        Mock Get-DMhostGroups { @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' }) }
        Mock Get-DMhostsbyHostGroupId { @([pscustomobject]@{ Id = 'host-01'; Name = 'server01' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'associates a resolved host with a resolved host group' {
        $result = Add-DMHostToHostGroup -WebSession $script:session -HostName 'server01' -HostGroupName 'cluster01' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'hostgroup/associate'
        $script:request.ID | Should -Be 'hg-01'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 21
        $script:request.ASSOCIATEOBJID | Should -Be 'host-01'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'removes a verified host membership' {
        $result = Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'server01' -HostGroupName 'cluster01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'host/associate'
        $script:request.ID | Should -Be 'hg-01'
        $script:request.ASSOCIATEOBJID | Should -Be 'host-01'
    }

    It 'rejects removal when the host is not a group member' {
        Mock Get-DMhostsbyHostGroupId { @() }

        { Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'server01' -HostGroupName 'cluster01' -Confirm:$false } |
            Should -Throw '*not a member*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}

Describe 'LUN group membership commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMluns { @([pscustomobject]@{ Id = 'lun-01'; Name = 'database' }) }
        Mock Get-DMlunGroups { @([pscustomobject]@{ Id = 'lg-01'; Name = 'production' }) }
        Mock Get-DMlunsbyLunGroup { @([pscustomobject]@{ Id = 'lun-01'; Name = 'database' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'associates a resolved LUN with host LUN ID options' {
        $result = Add-DMLunToLunGroup -WebSession $script:session -LunName 'database' -LunGroupName 'production' -HostLunId 5 -Force -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'lungroup/associate'
        $script:request.ID | Should -Be 'lg-01'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 11
        $script:request.ASSOCIATEOBJID | Should -Be 'lun-01'
        $script:request.hostLunID | Should -Be 5
        $script:request.force | Should -BeTrue
        $script:request.vstoreId | Should -Be '7'
    }

    It 'rejects mutually exclusive host LUN allocation values' {
        { Add-DMLunToLunGroup -WebSession $script:session -LunName 'database' -LunGroupName 'production' -HostLunId 5 -StartHostLunId 10 -Confirm:$false } |
            Should -Throw '*cannot be specified together*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'removes a verified LUN membership through query parameters' {
        $result = Remove-DMLunFromLunGroup -WebSession $script:session -LunName 'database' -LunGroupName 'production' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'lungroup/associate?ID=lg-01&ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=lun-01&vstoreId=7'
    }

    It 'honors WhatIf for association changes' {
        $null = Remove-DMLunFromLunGroup -WebSession $script:session -LunName 'database' -LunGroupName 'production' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
