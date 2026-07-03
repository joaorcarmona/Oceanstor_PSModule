BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMlunGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMlunGroup.ps1"

        Export-ModuleMember -Function Get-DMlunGroup
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMlunGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMlunGroupTestModule {
Describe 'Get-DMlunGroup' {
    BeforeEach {
        $script:session  = [pscustomobject]@{ version = 'V600R001' }
        $script:resource = $null
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @() }
        }
    }

    It 'queries the lungroup endpoint without a query string by default' {
        $null = Get-DMlunGroup -WebSession $script:session

        $script:resource | Should -BeLike 'lungroup*'
    }

    It 'appends ?vstoreId when VstoreId is supplied' {
        $null = Get-DMlunGroup -WebSession $script:session -VstoreId 'vs-01'

        $script:resource | Should -BeLike 'lungroup?vstoreId=vs-01*'
    }

    It 'does not append vstoreId when VstoreId is omitted' {
        $null = Get-DMlunGroup -WebSession $script:session

        $script:resource | Should -Not -BeLike '*vstoreId*'
    }

    It 'calls the API exactly once per invocation' {
        $null = Get-DMlunGroup -WebSession $script:session -VstoreId 'vs-01'

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'filters by positional Name using an exact server-side filter' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ ID = '1'; NAME = 'production-luns'; TYPE = 256; ISADD2MAPPINGVIEW = 'false' }) }
        }

        $result = @(Get-DMlunGroup -WebSession $script:session 'production-luns')

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'production-luns'
        $script:resource | Should -BeLike 'lungroup?filter=NAME::production-luns*'
    }

    It 'filters by Name using a fuzzy server-side hint for a wildcard keyword' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            if ($Resource -like 'lungroup?filter=NAME:prod*') {
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = '1'; NAME = 'production-luns'; TYPE = 256; ISADD2MAPPINGVIEW = 'false' }) }
            }
            [pscustomobject]@{ data = @() }
        }

        $result = @(Get-DMlunGroup -WebSession $script:session -Name 'prod*')

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'production-luns'
        $script:resource | Should -BeLike 'lungroup?filter=NAME:prod*'
    }

    It 'combines Name and VstoreId in the same query string' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @() }
        }

        $null = Get-DMlunGroup -WebSession $script:session -Name 'production-luns' -VstoreId 'vs-01'

        $script:resource | Should -BeLike 'lungroup?filter=NAME::production-luns&vstoreId=vs-01*'
    }
}
}
