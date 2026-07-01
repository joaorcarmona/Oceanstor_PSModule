BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMlunGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource)
        }

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

        $script:resource | Should -Be 'lungroup'
    }

    It 'appends ?vstoreId when VstoreId is supplied' {
        $null = Get-DMlunGroup -WebSession $script:session -VstoreId 'vs-01'

        $script:resource | Should -Be 'lungroup?vstoreId=vs-01'
    }

    It 'does not append vstoreId when VstoreId is omitted' {
        $null = Get-DMlunGroup -WebSession $script:session

        $script:resource | Should -Not -BeLike '*vstoreId*'
    }

    It 'calls the API exactly once per invocation' {
        $null = Get-DMlunGroup -WebSession $script:session -VstoreId 'vs-01'

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }
}
}
