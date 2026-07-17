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

        # Stub for the read side of the read-modify-write. The real Set-DMSnmpTrapServer
        # calls the sibling Get-DMSnmpTrapServer (same module in production); here we
        # provide a mockable stand-in so the unit stays isolated to the Set logic.
        function Get-DMSnmpTrapServer {
            param(
                [pscustomobject]$WebSession,
                [string]$Id
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

            # Current server state returned by the read half of read-modify-write.
            Mock Get-DMSnmpTrapServer {
                [pscustomobject]@{
                    Id      = $Id
                    Address = '10.0.0.9'
                    Port    = '162'
                    User    = 'existingUser'
                    Type    = '3'
                    Version = '1'
                }
            }

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

        It 're-supplies the mandatory IP/PORT from the read-back when only the ID is given' {
            # Regression guard for OceanStor API error 1077949001: a partial PUT body
            # (ID only, or ID + PORT) is rejected/times out because CMO_TRAP_SERVER_IP
            # and CMO_TRAP_SERVER_PORT are Mandatory. Read-modify-write must re-supply
            # them from the current server state.
            $null = Set-DMSnmpTrapServer -WebSession $script:session -Id '7' -Confirm:$false

            $script:lastResource | Should -Be 'snmp_trap_addr/7'
            $script:lastBody.ID | Should -Be '7'
            $script:lastBody.CMO_TRAP_SERVER_IP | Should -Be '10.0.0.9'
            $script:lastBody.CMO_TRAP_SERVER_PORT | Should -Be '162'
        }

        It 'overlays only the changed field, preserving the rest from the read-back' {
            # The integration workflow updates only the port; the address must be
            # carried over from the read-back so the modify body stays spec-valid.
            $null = Set-DMSnmpTrapServer -WebSession $script:session -Id '3' -Port 1162 -Confirm:$false

            $script:lastBody.CMO_TRAP_SERVER_PORT | Should -Be '1162'
            $script:lastBody.CMO_TRAP_SERVER_IP | Should -Be '10.0.0.9'
            $script:lastBody.CMO_TRAP_SERVER_USER | Should -Be 'existingUser'
            $script:lastBody.CMO_TRAP_SERVER_TYPE | Should -Be '3'
            $script:lastBody.CMO_TRAP_VERSION | Should -Be '1'
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
            Should -Invoke Get-DMSnmpTrapServer -Times 0
        }
    }
}
