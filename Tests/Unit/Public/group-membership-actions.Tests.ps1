BeforeDiscovery {
    $script:groupMembershipModule = New-Module -Name GroupMembershipTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMhostbyName { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMhostGroup { param([pscustomobject]$WebSession) }
        function Get-DMhostbyHostGroup { param([pscustomobject]$WebSession, [string]$HostGroupId) }
        function Get-DMlun { param([pscustomobject]$WebSession) }
        function Get-DMlunGroup { param([pscustomobject]$WebSession) }
        function Get-DMlunbyLunGroup { param([pscustomobject]$WebSession, [psobject]$LunGroup) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMHostToHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHostFromHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMLunToLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunFromLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunGroup.ps1"

        Export-ModuleMember -Function 'Add-DMHostToHostGroup', 'Remove-DMHostFromHostGroup', 'Add-DMLunToLunGroup', 'Remove-DMLunFromLunGroup', 'Remove-DMLunGroup'
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
        Mock Get-DMhostbyName { @([pscustomobject]@{ Id = 'host-01'; Name = 'server01' } | Where-Object Name -EQ $Name) }
        Mock Get-DMhostGroup { @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' }) }
        Mock Get-DMhostbyHostGroup { @([pscustomobject]@{ Id = 'host-01'; Name = 'server01' }) }
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
        Mock Get-DMhostbyHostGroup { @() }

        { Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'server01' -HostGroupName 'cluster01' -Confirm:$false } |
            Should -Throw '*not a member*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}

Describe 'LUN group membership commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlun { @([pscustomobject]@{ Id = 'lun-01'; Name = 'database' }) }
        Mock Get-DMlunGroup { @([pscustomobject]@{ Id = 'lg-01'; Name = 'production' }) }
        Mock Get-DMlunbyLunGroup { @([pscustomobject]@{ Id = 'lun-01'; Name = 'database' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'accepts a LUN object from the pipeline by property name' {
        $lun = [pscustomobject]@{ Id = 'lun-01'; Name = 'database' }

        $result = $lun | Add-DMLunToLunGroup -WebSession $script:session -LunGroupName 'production' -Confirm:$false

        $result.Code | Should -Be 0
        $script:request.ASSOCIATEOBJID | Should -Be 'lun-01'
        $script:request.ID | Should -Be 'lg-01'
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

    It 'associates every LUN piped in, not just the last one' {
        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'lun-b' }
            )
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Resource = $Resource; Body = $BodyData })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $luns = @(
            [pscustomobject]@{ Name = 'lun-a' }
            [pscustomobject]@{ Name = 'lun-b' }
        )
        $null = $luns | Add-DMLunToLunGroup -WebSession $script:session -LunGroupName 'production' -Confirm:$false

        $requests.Count | Should -Be 2
        ($requests | Where-Object { $_.Body.ASSOCIATEOBJID -eq 'lun-01' }).Count | Should -Be 1
        ($requests | Where-Object { $_.Body.ASSOCIATEOBJID -eq 'lun-02' }).Count | Should -Be 1
    }

    It 'continues processing remaining piped LUNs after one fails to resolve' {
        Mock Get-DMlun {
            @([pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a' })
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Resource = $Resource; Body = $BodyData })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $luns = @(
            [pscustomobject]@{ Name = 'lun-a' }
            [pscustomobject]@{ Name = 'missing-lun' }
        )
        $null = $luns | Add-DMLunToLunGroup -WebSession $script:session -LunGroupName 'production' -Confirm:$false `
            -ErrorAction SilentlyContinue -ErrorVariable addErrors

        $addErrors.Count | Should -BeGreaterOrEqual 1
        ($addErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid LunName*'
        $requests.Count | Should -Be 1
        $requests[0].Body.ASSOCIATEOBJID | Should -Be 'lun-01'
    }

    It 'removes every LUN membership piped in, not just the last one' {
        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'lun-b' }
            )
        }
        Mock Get-DMlunbyLunGroup {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'lun-b' }
            )
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Resource = $Resource })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $luns = @(
            [pscustomobject]@{ Name = 'lun-a' }
            [pscustomobject]@{ Name = 'lun-b' }
        )
        $null = $luns | Remove-DMLunFromLunGroup -WebSession $script:session -LunGroupName 'production' -Confirm:$false

        $requests.Count | Should -Be 2
        ($requests | Where-Object { $_.Resource -like '*ASSOCIATEOBJID=lun-01*' }).Count | Should -Be 1
        ($requests | Where-Object { $_.Resource -like '*ASSOCIATEOBJID=lun-02*' }).Count | Should -Be 1
    }
}

Describe 'Remove-DMLunGroup' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlunGroup {
            @(
                [pscustomobject]@{ Id = 'lg-01'; Name = 'group-a' }
                [pscustomobject]@{ Id = 'lg-02'; Name = 'group-b' }
            )
        }
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'removes every LUN group piped in, not just the last one' {
        $groups = @(
            [pscustomobject]@{ Name = 'group-a' }
            [pscustomobject]@{ Name = 'group-b' }
        )
        $null = $groups | Remove-DMLunGroup -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lungroup/lg-01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lungroup/lg-02' }
    }

    It 'continues processing remaining piped LUN groups after one fails to resolve' {
        $groups = @(
            [pscustomobject]@{ Name = 'group-a' }
            [pscustomobject]@{ Name = 'missing-group' }
        )
        $null = $groups | Remove-DMLunGroup -WebSession $script:session -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid LunGroupName*'
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lungroup/lg-01' }
    }
}
}
