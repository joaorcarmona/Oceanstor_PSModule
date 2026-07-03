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

    It 'reports a non-terminating error when the host is not a member of the host group' {
        Mock Get-DMhostbyHostGroup { @() }

        $result = Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'web-host' -HostGroupName 'prod-group' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*not a member*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error for a host name that does not exist' {
        $result = Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'missing' -HostGroupName 'prod-group' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid HostName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error for a host group name that does not exist' {
        $result = Remove-DMHostFromHostGroup -WebSession $script:session -HostName 'web-host' -HostGroupName 'missing' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid HostGroupName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'removes every host piped in, not just the last one' {
        Mock Get-DMhostbyName {
            @([pscustomobject]@{ Id = "id-$Name"; Name = $Name })
        }
        Mock Get-DMhostbyHostGroup {
            @([pscustomobject]@{ Id = 'id-host-a'; Name = 'host-a' }, [pscustomobject]@{ Id = 'id-host-b'; Name = 'host-b' })
        }

        $hosts = @([pscustomobject]@{ Name = 'host-a' }, [pscustomobject]@{ Name = 'host-b' })
        $null = $hosts | Remove-DMHostFromHostGroup -WebSession $script:session -HostGroupName 'prod-group' -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $BodyData.ASSOCIATEOBJID -eq 'id-host-a' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $BodyData.ASSOCIATEOBJID -eq 'id-host-b' }
    }
}
}
