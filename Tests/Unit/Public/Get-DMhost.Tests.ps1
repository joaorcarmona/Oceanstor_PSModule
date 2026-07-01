BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMhostTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource)
        }
        function Set-DMHostInitiator {
            param([object[]]$InputObject, [pscustomobject]$WebSession)
            $InputObject
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMhost.ps1"

        Export-ModuleMember -Function Get-DMhost
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMhostTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMhostTestModule {
Describe 'Get-DMhost' {
    BeforeEach {
        $script:session  = [pscustomobject]@{ version = 'V600R001' }
        $script:resource = $null
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @() }
        }
    }

    It 'queries the host endpoint without a query string by default' {
        $null = Get-DMhost -WebSession $script:session

        $script:resource | Should -Be 'host'
    }

    It 'appends ?vstoreId when VstoreId is supplied' {
        $null = Get-DMhost -WebSession $script:session -VstoreId 'vs-01'

        $script:resource | Should -Be 'host?vstoreId=vs-01'
    }

    It 'does not append vstoreId when VstoreId is omitted' {
        $null = Get-DMhost -WebSession $script:session

        $script:resource | Should -Not -BeLike '*vstoreId*'
    }

    It 'calls the API exactly once per invocation' {
        $null = Get-DMhost -WebSession $script:session -VstoreId 'vs-01'

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }
}
}
