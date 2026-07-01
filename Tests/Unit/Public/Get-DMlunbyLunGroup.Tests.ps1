BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMlunbyLunGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlun { param([pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMlunbyLunGroup.ps1"

        Export-ModuleMember -Function Get-DMlunbyLunGroup
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMlunbyLunGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMlunbyLunGroupTestModule {
Describe 'Get-DMlunbyLunGroup' {
    BeforeEach {
        $script:session  = [pscustomobject]@{ version = 'V600R001' }
        $script:lunGroup = [pscustomobject]@{ Id = 'lg-01'; Name = 'web-luns' }

        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = '1'; Name = 'lun-a' }
                [pscustomobject]@{ Id = '2'; Name = 'lun-b' }
                [pscustomobject]@{ Id = '3'; Name = 'lun-c' }
            )
        }
    }

    It 'returns LUNs when ASSOCIATELUNIDLIST is a native array' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = @('1', '2') } }
        }

        $result = Get-DMlunbyLunGroup -WebSession $script:session -LunGroup $script:lunGroup

        $result.Count | Should -Be 2
        $result.Name  | Should -Contain 'lun-a'
        $result.Name  | Should -Contain 'lun-b'
    }

    It 'parses ASSOCIATELUNIDLIST when returned as a JSON array string' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '["1","2"]' } }
        }

        $result = Get-DMlunbyLunGroup -WebSession $script:session -LunGroup $script:lunGroup

        $result.Count | Should -Be 2
        $result.Name  | Should -Contain 'lun-a'
        $result.Name  | Should -Contain 'lun-b'
    }

    It 'parses ASSOCIATELUNIDLIST correctly when JSON parse fails and brackets are present' {
        # Simulate a PS build where ConvertFrom-Json fails on the input. The fallback must
        # strip [ ] before splitting so "[1,2,3]" → "1","2","3", not "[1","2","3]".
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '[1,2]' } }
        }
        Mock ConvertFrom-Json { throw 'simulated parse failure' }

        $result = Get-DMlunbyLunGroup -WebSession $script:session -LunGroup $script:lunGroup

        $result.Count | Should -Be 2
        $result.Name  | Should -Contain 'lun-a'
        $result.Name  | Should -Contain 'lun-b'
    }

    It 'parses ASSOCIATELUNIDLIST when returned as a plain CSV string without brackets' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '1,2' } }
        }
        Mock ConvertFrom-Json { throw 'simulated parse failure' }

        $result = Get-DMlunbyLunGroup -WebSession $script:session -LunGroup $script:lunGroup

        $result.Count | Should -Be 2
    }

    It 'returns an empty array when the group has no associated LUNs' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = $null } }
        }

        $result = Get-DMlunbyLunGroup -WebSession $script:session -LunGroup $script:lunGroup

        @($result).Count | Should -Be 0
    }

    It 'returns an empty array when the API response has no data property' {
        Mock Invoke-DeviceManager { [pscustomobject]@{} }

        $result = Get-DMlunbyLunGroup -WebSession $script:session -LunGroup $script:lunGroup

        @($result).Count | Should -Be 0
    }
}
}
