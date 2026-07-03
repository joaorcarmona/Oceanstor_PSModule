BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMlunbyLunGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlun { param([pscustomobject]$WebSession, $LunGroup, $LunGroupName, $LunGroupId) }
        function Get-DMlunGroup { param([pscustomobject]$WebSession, [string]$Name) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMlunbyLunGroup.ps1"

        Export-ModuleMember -Function Get-DMlunbyLunGroup
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMlunbyLunGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMlunbyLunGroupTestModule {
Describe 'Get-DMlunbyLunGroup (legacy wrapper)' {
    BeforeEach {
        $script:session  = [pscustomobject]@{ version = 'V600R001' }
        $script:lunGroup = [pscustomobject]@{ Id = 'lg-01'; Name = 'web-luns' }

        Mock Get-DMlunGroup {
            param($WebSession, $Name)
            $groups = @([pscustomobject]@{ Id = 'lg-01'; Name = 'web-luns' })
            if ($Name) { return @($groups | Where-Object Name -EQ $Name) }
            $groups
        }
    }

    It 'forwards a piped LunGroup object to Get-DMlun' {
        Mock Get-DMlun { [pscustomobject]@{ Id = '1'; Name = 'lun-a' } }

        $result = @(Get-DMlunbyLunGroup -WebSession $script:session -LunGroup $script:lunGroup)

        $result[0].Name | Should -Be 'lun-a'
        Should -Invoke Get-DMlun -Times 1 -Exactly -ParameterFilter {
            $LunGroup -eq $script:lunGroup -and $WebSession -eq $script:session
        }
    }

    It 'forwards LunGroupName to Get-DMlun after resolving it' {
        Mock Get-DMlun { [pscustomobject]@{ Id = '1'; Name = 'lun-a' } }

        $result = @(Get-DMlunbyLunGroup -WebSession $script:session -LunGroupName 'web-luns')

        $result[0].Name | Should -Be 'lun-a'
        Should -Invoke Get-DMlun -Times 1 -Exactly -ParameterFilter {
            $LunGroupName -eq 'web-luns' -and $WebSession -eq $script:session
        }
    }

    It 'rejects a LunGroupName that does not exist, before calling Get-DMlun' {
        Mock Get-DMlun { [pscustomobject]@{ Id = '1'; Name = 'lun-a' } }

        { Get-DMlunbyLunGroup -WebSession $script:session -LunGroupName 'missing' } |
            Should -Throw '*Invalid LunGroupName*'

        Should -Invoke Get-DMlun -Times 0 -Exactly
    }

    It 'forwards LunGroupId to Get-DMlun without validating it first' {
        Mock Get-DMlun { [pscustomobject]@{ Id = '1'; Name = 'lun-a' } }

        $result = @(Get-DMlunbyLunGroup -WebSession $script:session -LunGroupId 'lg-99')

        $result[0].Name | Should -Be 'lun-a'
        Should -Invoke Get-DMlunGroup -Times 0 -Exactly
        Should -Invoke Get-DMlun -Times 1 -Exactly -ParameterFilter {
            $LunGroupId -eq 'lg-99' -and $WebSession -eq $script:session
        }
    }

    It 'exposes completion metadata for LunGroupName' {
        $command = Get-Command Get-DMlunbyLunGroup
        @($command.Parameters['LunGroupName'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
            Should -BeGreaterThan 0 -Because 'Get-DMlunbyLunGroup -LunGroupName should support tab completion'
    }

    It 'warns about deprecation' {
        Mock Get-DMlun { [pscustomobject]@{ Id = '1'; Name = 'lun-a' } }

        Get-DMlunbyLunGroup -WebSession $script:session -LunGroup $script:lunGroup -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

        $warnings.Count | Should -Be 1
        $warnings[0] | Should -Match 'deprecated'
    }
}
}
