BeforeDiscovery {
    $script:quorumModule = New-Module -Name QuorumServerTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorQuorumServer.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMQuorumServer.ps1"

        Export-ModuleMember -Function 'Get-DMQuorumServer'
    }

    Import-Module $script:quorumModule -Force
}

AfterAll {
    Remove-Module -Name QuorumServerTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope QuorumServerTestModule {
    Describe 'Get-DMQuorumServer' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001' }
            $script:resource = $null
            $script:method = $null
        }

        It 'lists quorum servers from the documented QuorumServer collection resource' {
            Mock Invoke-DeviceManager {
                $script:method = $Method
                $script:resource = $Resource
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @(
                        [pscustomobject]@{ ID = '0'; NAME = 'quorum-a'; RUNNINGSTATUS = '27'; DESCRIPTION = 'primary'; SERVERIPA = '3.3.3.6'; SERVERPORTA = '30002'; SERVERIPB = ''; SERVERPORTB = ''; DEVICESN = 'SN01'; USERNAME = '' }
                        [pscustomobject]@{ ID = '1'; NAME = 'quorum-b'; RUNNINGSTATUS = '28'; DESCRIPTION = ''; SERVERIPA = '3.3.3.7'; SERVERPORTA = '30002'; SERVERIPB = ''; SERVERPORTB = ''; DEVICESN = 'SN02'; USERNAME = '' }
                    )
                }
            }

            $result = @(Get-DMQuorumServer -WebSession $script:session)

            $result.Count | Should -Be 2
            $result[0].GetType().Name | Should -Be 'OceanStorQuorumServer'
            $result[0].'Running Status' | Should -Be 'Online'
            $result[1].'Running Status' | Should -Be 'Offline'
            $result[0].'Primary IP Address' | Should -Be '3.3.3.6'
            $script:resource | Should -BeLike 'QuorumServer?range=*'
        }

        It 'filters by -Name wildcard client-side' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @(
                        [pscustomobject]@{ ID = '0'; NAME = 'quorum-a'; RUNNINGSTATUS = '27' }
                        [pscustomobject]@{ ID = '1'; NAME = 'quorum-b'; RUNNINGSTATUS = '28' }
                    )
                }
            }

            $result = @(Get-DMQuorumServer -WebSession $script:session -Name 'quorum-a')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'quorum-a'
        }

        It 'gets one quorum server by exact id from QuorumServer/{id}' {
            Mock Invoke-DeviceManager {
                $script:resource = $Resource
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = [pscustomobject]@{ ID = '0'; NAME = 'quorum-a'; RUNNINGSTATUS = '27'; SERVERIPA = '3.3.3.6' }
                }
            }

            $result = Get-DMQuorumServer -WebSession $script:session -Id '0'

            $result.GetType().Name | Should -Be 'OceanStorQuorumServer'
            $result.Name | Should -Be 'quorum-a'
            $script:resource | Should -Be 'QuorumServer/0'
        }

        It 'tolerates an empty quorum server inventory' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
            }

            $result = @(Get-DMQuorumServer -WebSession $script:session)

            $result.Count | Should -Be 0
        }

        It 'preserves an unmapped running status code as the raw value' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @([pscustomobject]@{ ID = '0'; NAME = 'quorum-a'; RUNNINGSTATUS = '999' })
                }
            }

            $result = @(Get-DMQuorumServer -WebSession $script:session)

            $result[0].'Running Status' | Should -Be '999'
            $result[0].'Running Status Code' | Should -Be '999'
        }
    }
}
