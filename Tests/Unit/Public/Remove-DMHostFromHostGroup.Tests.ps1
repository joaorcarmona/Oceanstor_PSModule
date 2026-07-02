BeforeDiscovery {
    $script:testModule = New-Module -Name RemoveDMHostFromHostGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMhostbyName       { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMhostGroup        { param([pscustomobject]$WebSession) }
        function Get-DMhostbyHostGroup { param([pscustomobject]$WebSession, [string]$HostGroupId) }
        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource, [hashtable]$BodyData)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHostFromHostGroup.ps1"

        Export-ModuleMember -Function Remove-DMHostFromHostGroup
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name RemoveDMHostFromHostGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope RemoveDMHostFromHostGroupTestModule {
Describe 'Remove-DMHostFromHostGroup' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMhostbyName {
            @([pscustomobject]@{ Id = 'host-01'; Name = 'web-host' } | Where-Object Name -EQ $Name)
        }
        Mock Get-DMhostGroup {
            @([pscustomobject]@{ Id = 'grp-01'; Name = 'prod-group' })
        }
        Mock Get-DMhostbyHostGroup {
            @([pscustomobject]@{ Id = 'host-01'; Name = 'web-host' })
        }
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'removes a host from a host group and calls the API exactly once' {
        $result = Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'web-host' -HostGroupName 'prod-group' -Confirm:$false

        $result.Code | Should -Be 0
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and $Resource -eq 'host/associate' -and
            $BodyData.ID -eq 'grp-01' -and $BodyData.ASSOCIATEOBJID -eq 'host-01'
        }
    }

    It 'calls Get-DMhostbyName only once per invocation (no redundant API round-trip)' {
        $null = Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'web-host' -HostGroupName 'prod-group' -Confirm:$false

        Should -Invoke Get-DMhostbyName -Times 1 -Exactly
    }

    It 'calls Get-DMhostGroup only once per invocation (no redundant API round-trip)' {
        $null = Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'web-host' -HostGroupName 'prod-group' -Confirm:$false

        Should -Invoke Get-DMhostGroup -Times 1 -Exactly
    }

    It 'does not call the API when WhatIf is specified' {
        $null = Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'web-host' -HostGroupName 'prod-group' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'throws when the host is not a member of the host group' {
        Mock Get-DMhostbyHostGroup { @() }

        { Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'web-host' -HostGroupName 'prod-group' -Confirm:$false } |
            Should -Throw "*not a member*"

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a host name that does not exist' {
        { Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'missing' -HostGroupName 'prod-group' -Confirm:$false } |
            Should -Throw '*Invalid HostName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a host group name that does not exist' {
        { Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'web-host' -HostGroupName 'missing' -Confirm:$false } |
            Should -Throw '*Invalid HostGroupName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
