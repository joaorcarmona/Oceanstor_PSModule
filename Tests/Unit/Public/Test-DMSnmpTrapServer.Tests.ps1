BeforeDiscovery {
    $script:testSnmpTrapModule = New-Module -Name TestSnmpTrapServerTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Test-DMSnmpTrapServer.ps1"

        Export-ModuleMember -Function 'Test-DMSnmpTrapServer'
    }

    Import-Module $script:testSnmpTrapModule -Force
}

AfterAll {
    Remove-Module -Name TestSnmpTrapServerTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope TestSnmpTrapServerTestModule {
    Describe 'Test-DMSnmpTrapServer' {
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

        It 'PUTs to snmp_trap_addr/send_test_trapmsg with IP and port' {
            $null = Test-DMSnmpTrapServer -WebSession $script:session -Address '192.168.0.1' -Port 162

            $script:lastMethod | Should -Be 'PUT'
            $script:lastResource | Should -Be 'snmp_trap_addr/send_test_trapmsg'
            $script:lastBody.CMO_TRAP_SERVER_IP | Should -Be '192.168.0.1'
            $script:lastBody.CMO_TRAP_SERVER_PORT | Should -Be '162'
        }

        It 'always sends the Mandatory type and version fields, defaulting when omitted' {
            # Regression guard for OceanStor API error 50331651: the send-test interface
            # marks CMO_TRAP_SERVER_TYPE and CMO_TRAP_VERSION as Mandatory.
            $null = Test-DMSnmpTrapServer -WebSession $script:session -Address '192.168.0.1' -Port 162

            $script:lastBody.CMO_TRAP_SERVER_TYPE | Should -Be '3'
            $script:lastBody.CMO_TRAP_VERSION | Should -Be '1'
        }

        It 'honors caller-supplied type and version overrides' {
            $null = Test-DMSnmpTrapServer -WebSession $script:session -Address '192.168.0.1' -Port 162 -Type '1' -Version '3' -User 'usmuser'

            $script:lastBody.CMO_TRAP_SERVER_TYPE | Should -Be '1'
            $script:lastBody.CMO_TRAP_VERSION | Should -Be '3'
            $script:lastBody.CMO_TRAP_SERVER_USER | Should -Be 'usmuser'
        }

        It 'returns the API error object on success' {
            $result = Test-DMSnmpTrapServer -WebSession $script:session -Address '192.168.0.1' -Port 162

            $result.code | Should -Be 0
        }
    }
}
