BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMhostbyHostGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMhostGroup { param([pscustomobject]$WebSession) }
        function Set-DMHostInitiator { param([object[]]$InputObject, [pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMhostbyHostGroup.ps1"

        Export-ModuleMember -Function Get-DMhostbyHostGroup
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMhostbyHostGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMhostbyHostGroupTestModule {
Describe 'Get-DMhostbyHostGroup' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:hostGroup = [pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' }
        $script:requestedResource = $null

        Mock Get-DMhostGroup {
            @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' })
        }
        Mock Set-DMHostInitiator {
            param($InputObject, $WebSession)
            $InputObject
        }
    }

    It 'returns hosts associated with the group when a HostGroup object is supplied' {
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource)
            $script:requestedResource = $Resource
            [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'host-01'; NAME = 'server-a'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 21 }
                ) }
        }

        $result = Get-DMhostbyHostGroup -WebSession $script:session -HostGroup $script:hostGroup

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'server-a'
        $script:requestedResource | Should -Be 'host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=hg-01'
    }

    It 'resolves the group by name when HostGroupName is supplied' {
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource)
            $script:requestedResource = $Resource
            [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'host-01'; NAME = 'server-a'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 21 }
                ) }
        }

        $result = Get-DMhostbyHostGroup -WebSession $script:session -HostGroupName 'cluster01'

        $result.Count | Should -Be 1
        $script:requestedResource | Should -Be 'host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=hg-01'
    }

    It 'rejects a HostGroupName that does not exist' {
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }

        { Get-DMhostbyHostGroup -WebSession $script:session -HostGroupName 'missing' } |
            Should -Throw '*Invalid HostGroupName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'resolves the group by ID when HostGroupId is supplied, without validating it first' {
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource)
            $script:requestedResource = $Resource
            [pscustomobject]@{ data = @() }
        }

        $result = @(Get-DMhostbyHostGroup -WebSession $script:session -HostGroupId 'hg-99')

        $result.Count | Should -Be 0
        $script:requestedResource | Should -Be 'host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=hg-99'
        Should -Invoke Get-DMhostGroup -Times 0 -Exactly
    }

    It 'returns an empty array when the group has no associated hosts' {
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }

        $result = Get-DMhostbyHostGroup -WebSession $script:session -HostGroup $script:hostGroup

        @($result).Count | Should -Be 0
    }

    It 'exposes completion metadata for HostGroupName' {
        $command = Get-Command Get-DMhostbyHostGroup
        @($command.Parameters['HostGroupName'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
            Should -BeGreaterThan 0 -Because 'Get-DMhostbyHostGroup -HostGroupName should support tab completion'
    }
}
}
