BeforeDiscovery {
    $script:setVlanModule = New-Module -Name SetVlanTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [int]$TimeoutSec,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMvLan.ps1"

        Export-ModuleMember -Function 'Set-DMvLan'
    }

    Import-Module $script:setVlanModule -Force
}

AfterAll {
    Remove-Module -Name SetVlanTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SetVlanTestModule {
    Describe 'Set-DMvLan' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001' }
            $script:lastMethod = $null
            $script:lastResource = $null
            $script:lastBody = $null

            Mock Invoke-DeviceManager {
                $script:lastMethod = $Method
                $script:lastResource = $Resource
                $script:lastBody = $BodyData
                [pscustomobject]@{
                    data  = [pscustomobject]@{}
                    error = [pscustomobject]@{ code = 0; description = '0' }
                }
            }
        }

        It 'PUTs to vlan/{id} with both the ID and MTU echoed in the request body' {
            # Regression guard for OceanStor API error 50331651: the modify interface
            # (REST reference 4.6.9.3.8) marks both ID and MTU as Mandatory body fields;
            # sending MTU alone (ID only in the URL path) is rejected by the array.
            $null = Set-DMvLan -WebSession $script:session -Id '4261543937' -Mtu 1502 -Confirm:$false

            $script:lastMethod | Should -Be 'PUT'
            $script:lastResource | Should -Be 'vlan/4261543937'
            $script:lastBody.ID | Should -Be '4261543937'
            $script:lastBody.MTU | Should -Be 1502
        }

        It 'returns the API error object on success' {
            $result = Set-DMvLan -WebSession $script:session -Id '4261543937' -Mtu 1502 -Confirm:$false

            $result.code | Should -Be 0
        }

        It 'does not call the API under -WhatIf' {
            $null = Set-DMvLan -WebSession $script:session -Id '4261543937' -Mtu 1502 -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0
        }
    }
}
