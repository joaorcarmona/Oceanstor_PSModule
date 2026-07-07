BeforeDiscovery {
    $script:drDomainModule = New-Module -Name DrDomainLifecycleTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource, [hashtable]$BodyData)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Resolve-DMDrPairHelper.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMQuorumServerToHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMQuorumServerFromHyperMetroDomain.ps1"

        Export-ModuleMember -Function '*-DM*'
    }

    Import-Module $script:drDomainModule -Force
}

AfterAll {
    Remove-Module -Name DrDomainLifecycleTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope DrDomainLifecycleTestModule {
Describe 'HyperMetro SAN domain lifecycle commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:remoteDevices = @(
            @{
                devId   = 'remote-01'
                devESN  = '210235G6LLZ0B8000002'
                devName = 'remote-array'
            }
        )
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @([pscustomobject]@{
                            ID            = 'domain-01'
                            NAME          = 'metro-domain'
                            DOMAINTYPE    = '1'
                            REMOTEDEVICES = '[]'
                        })
                }
            }
            return [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = [pscustomobject]@{
                    ID            = 'domain-new'
                    NAME          = 'metro-domain'
                    DOMAINTYPE    = '1'
                    REMOTEDEVICES = '[]'
                }
            }
        }
    }

    It 'creates a SAN HyperMetro domain' {
        $result = New-DMHyperMetroDomain -WebSession $script:session -Name 'metro-domain' `
            -Description 'dr domain' -RemoteDevices $script:remoteDevices -DomainType AA -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorHyperMetroDomain'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'HyperMetroDomain'
        $script:request.NAME | Should -Be 'metro-domain'
        $script:request.DESCRIPTION | Should -Be 'dr domain'
        $script:request.DOMAINTYPE | Should -Be 1
        $script:request.REMOTEDEVICES[0].devId | Should -Be 'remote-01'
    }

    It 'modifies a SAN HyperMetro domain by id' {
        $result = Set-DMHyperMetroDomain -WebSession $script:session -Id 'domain-01' `
            -NewName 'metro-domain-renamed' -Description 'updated' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'HyperMetroDomain/domain-01'
        $script:request.ID | Should -Be 'domain-01'
        $script:request.NAME | Should -Be 'metro-domain-renamed'
        $script:request.DESCRIPTION | Should -Be 'updated'
    }

    It 'removes a SAN HyperMetro domain by name' {
        $result = Remove-DMHyperMetroDomain -WebSession $script:session -Name 'metro-domain' -LocalDelete $true -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'HyperMetroDomain/domain-01?ISLOCALDELETE=true'
    }

    It '<Command> calls <Resource>' -ForEach @(
        @{ Command = 'Add-DMQuorumServerToHyperMetroDomain'; Resource = 'HyperMetroDomain/CREATE_ASSOCIATE'; Method = 'POST' }
        @{ Command = 'Remove-DMQuorumServerFromHyperMetroDomain'; Resource = 'HyperMetroDomain/REMOVE_ASSOCIATE'; Method = 'PUT' }
    ) {
        $result = & $Command -WebSession $script:session -Id 'domain-01' -QuorumServerId 'quorum-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be $Method
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'domain-01'
        $script:request.ASSOCIATEOBJID | Should -Be 'quorum-01'
    }
}
}
