BeforeDiscovery {
    $script:setSnmpTrapModule = New-Module -Name SetSnmpTrapServerTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Test-DMNetworkAddress.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMSnmpTrapServer.ps1"

        Export-ModuleMember -Function 'Set-DMSnmpTrapServer'
    }

    Import-Module $script:setSnmpTrapModule -Force
}

AfterAll {
    Remove-Module -Name SetSnmpTrapServerTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SetSnmpTrapServerTestModule {
    Describe 'Set-DMSnmpTrapServer' {
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
                    data  = [pscustomobject]@{ ID = '2'; TYPE = 240 }
                    error = [pscustomobject]@{ code = 0; description = '0' }
                }
            }
        }

        It 'PUTs to snmp_trap_addr/{id} with the ID echoed in the request body' {
            # Regression guard for OceanStor API error 50331651: the modify interface
            # requires the object ID in the body as well as the URL path.
            $null = Set-DMSnmpTrapServer -WebSession $script:session -Id '2' -Address '192.168.0.1' -Port 162 -Confirm:$false

            $script:lastMethod | Should -Be 'PUT'
            $script:lastResource | Should -Be 'snmp_trap_addr/2'
            $script:lastBody.ID | Should -Be '2'
            $script:lastBody.CMO_TRAP_SERVER_IP | Should -Be '192.168.0.1'
            $script:lastBody.CMO_TRAP_SERVER_PORT | Should -Be '162'
        }

        It 'still includes the ID in the body when no other fields are supplied' {
            $null = Set-DMSnmpTrapServer -WebSession $script:session -Id '7' -Confirm:$false

            $script:lastResource | Should -Be 'snmp_trap_addr/7'
            $script:lastBody.ID | Should -Be '7'
        }

        It 'passes optional USM/type/version fields through when supplied' {
            $null = Set-DMSnmpTrapServer -WebSession $script:session -Id '2' -Address '192.168.0.1' -Port 162 -User 'usmuser' -Type '3' -Version '3' -Confirm:$false

            $script:lastBody.CMO_TRAP_SERVER_USER | Should -Be 'usmuser'
            $script:lastBody.CMO_TRAP_SERVER_TYPE | Should -Be '3'
            $script:lastBody.CMO_TRAP_VERSION | Should -Be '3'
        }

        It 'returns the API error object on success' {
            $result = Set-DMSnmpTrapServer -WebSession $script:session -Id '2' -Address '192.168.0.1' -Port 162 -Confirm:$false

            $result.code | Should -Be 0
        }

        It 'does not call the API under -WhatIf' {
            $null = Set-DMSnmpTrapServer -WebSession $script:session -Id '2' -Address '192.168.0.1' -Port 162 -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0
        }
    }
}
