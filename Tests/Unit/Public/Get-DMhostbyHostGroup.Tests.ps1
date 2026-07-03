BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMhostbyHostGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMhost { param([pscustomobject]$WebSession, $HostGroup, $HostGroupName, $HostGroupId) }
        function Get-DMhostGroup { param([pscustomobject]$WebSession, [string]$Name) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMhostbyHostGroup.ps1"

        Export-ModuleMember -Function Get-DMhostbyHostGroup
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMhostbyHostGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMhostbyHostGroupTestModule {
Describe 'Get-DMhostbyHostGroup (legacy wrapper)' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:hostGroup = [pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' }

        Mock Get-DMhostGroup {
            param($WebSession, $Name)
            $groups = @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' })
            if ($Name) { return @($groups | Where-Object Name -EQ $Name) }
            $groups
        }
    }

    It 'forwards a piped HostGroup object to Get-DMhost' {
        Mock Get-DMhost { [pscustomobject]@{ Id = 'host-01'; Name = 'server-a' } }

        $result = @(Get-DMhostbyHostGroup -WebSession $script:session -HostGroup $script:hostGroup)

        $result[0].Name | Should -Be 'server-a'
        Should -Invoke Get-DMhost -Times 1 -Exactly -ParameterFilter {
            $HostGroup -eq $script:hostGroup -and $WebSession -eq $script:session
        }
    }

    It 'forwards HostGroupName to Get-DMhost after resolving it' {
        Mock Get-DMhost { [pscustomobject]@{ Id = 'host-01'; Name = 'server-a' } }

        $result = @(Get-DMhostbyHostGroup -WebSession $script:session -HostGroupName 'cluster01')

        $result[0].Name | Should -Be 'server-a'
        Should -Invoke Get-DMhost -Times 1 -Exactly -ParameterFilter {
            $HostGroupName -eq 'cluster01' -and $WebSession -eq $script:session
        }
    }

    It 'rejects a HostGroupName that does not exist, before calling Get-DMhost' {
        Mock Get-DMhost { [pscustomobject]@{ Id = 'host-01'; Name = 'server-a' } }

        { Get-DMhostbyHostGroup -WebSession $script:session -HostGroupName 'missing' } |
            Should -Throw '*Invalid HostGroupName*'

        Should -Invoke Get-DMhost -Times 0 -Exactly
    }

    It 'forwards HostGroupId to Get-DMhost without validating it first' {
        Mock Get-DMhost { [pscustomobject]@{ Id = 'host-01'; Name = 'server-a' } }

        $result = @(Get-DMhostbyHostGroup -WebSession $script:session -HostGroupId 'hg-99')

        $result[0].Name | Should -Be 'server-a'
        Should -Invoke Get-DMhostGroup -Times 0 -Exactly
        Should -Invoke Get-DMhost -Times 1 -Exactly -ParameterFilter {
            $HostGroupId -eq 'hg-99' -and $WebSession -eq $script:session
        }
    }

    It 'exposes completion metadata for HostGroupName' {
        $command = Get-Command Get-DMhostbyHostGroup
        @($command.Parameters['HostGroupName'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
            Should -BeGreaterThan 0 -Because 'Get-DMhostbyHostGroup -HostGroupName should support tab completion'
    }

    It 'warns about deprecation' {
        Mock Get-DMhost { [pscustomobject]@{ Id = 'host-01'; Name = 'server-a' } }

        Get-DMhostbyHostGroup -WebSession $script:session -HostGroup $script:hostGroup -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

        $warnings.Count | Should -Be 1
        $warnings[0] | Should -Match 'deprecated'
    }
}
}
