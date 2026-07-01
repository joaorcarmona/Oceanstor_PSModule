BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMhostGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMhostGroup.ps1"

        Export-ModuleMember -Function Get-DMhostGroup
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMhostGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMhostGroupTestModule {
Describe 'Get-DMhostGroup' {
    BeforeEach {
        $script:session  = [pscustomobject]@{ version = 'V600R001' }
        $script:resource = $null
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @() }
        }
    }

    It 'queries the hostgroup endpoint without a query string by default' {
        $null = Get-DMhostGroup -WebSession $script:session

        $script:resource | Should -Be 'hostgroup'
    }

    It 'appends ?vstoreId when VstoreId is supplied' {
        $null = Get-DMhostGroup -WebSession $script:session -VstoreId 'vs-01'

        $script:resource | Should -Be 'hostgroup?vstoreId=vs-01'
    }

    It 'does not append vstoreId when VstoreId is omitted' {
        $null = Get-DMhostGroup -WebSession $script:session

        $script:resource | Should -Not -BeLike '*vstoreId*'
    }

    It 'calls the API exactly once per invocation' {
        $null = Get-DMhostGroup -WebSession $script:session -VstoreId 'vs-01'

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }
}
}
