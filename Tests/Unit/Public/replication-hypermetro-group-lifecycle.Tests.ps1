BeforeDiscovery {
    $script:drGroupModule = New-Module -Name DrGroupLifecycleTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource, [hashtable]$BodyData)
        }
        function Get-DMHyperMetroDomain { param([pscustomobject]$WebSession, [string]$Name) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Resolve-DMDrPairHelper.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMReplicationPairToConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMReplicationPairFromConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Sync-DMReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Split-DMReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Switch-DMReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMHyperMetroPairToConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHyperMetroPairFromConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Sync-DMHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Suspend-DMHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Start-DMHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Switch-DMHyperMetroConsistencyGroup.ps1"

        Export-ModuleMember -Function '*-DM*'
    }

    Import-Module $script:drGroupModule -Force
}

AfterAll {
    Remove-Module -Name DrGroupLifecycleTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope DrGroupLifecycleTestModule {
Describe 'Remote replication consistency group lifecycle commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = 'rcg-01'; NAME = 'rcg-a' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'rcg-new'; NAME = 'rcg-new' } }
        }
    }

    It 'creates a remote replication consistency group with documented create fields' {
        $result = New-DMReplicationConsistencyGroup -WebSession $script:session -Name 'rcg-new' -RemoteDeviceId 'remote-01' `
            -LocalProtectionGroupId 'lpg-01' -RemoteProtectionGroupId 'rpg-01' -ReplicationMode Async `
            -SynchronizationType TimedWaitAfterSync -TimingValueInSeconds 3600 -RecoveryPolicy Manual -Speed High -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorReplicationConsistencyGroup'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'CONSISTENTGROUP'
        $script:request.NAME | Should -Be 'rcg-new'
        $script:request.LOCALRESTYPE | Should -Be 11
        $script:request.REPLICATIONMODEL | Should -Be '2'
        $script:request.SYNCHRONIZETYPE | Should -Be '3'
        $script:request.TIMINGVALINSEC | Should -Be 3600
        $script:request.remoteArrayID | Should -Be 'remote-01'
        $script:request.localpgId | Should -Be 'lpg-01'
        $script:request.rmtpgId | Should -Be 'rpg-01'
    }

    It 'modifies a remote replication consistency group by id' {
        $result = Set-DMReplicationConsistencyGroup -WebSession $script:session -Id 'rcg-01' -Speed Highest `
            -SynchronizationType Manual -RecoveryPolicy Automatic -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'CONSISTENTGROUP/rcg-01'
        $script:request.SPEED | Should -Be '4'
        $script:request.SYNCHRONIZETYPE | Should -Be '1'
        $script:request.RECOVERYPOLICY | Should -Be '1'
    }

    It 'adds and removes a replication pair using documented mirror association payloads' {
        $null = Add-DMReplicationPairToConsistencyGroup -WebSession $script:session -GroupId 'rcg-01' -PairId 'rp-01' -Confirm:$false
        $script:resource | Should -Be 'ADD_MIRROR'
        $script:request.ID | Should -Be 'rcg-01'
        $script:request.RMLIST[0] | Should -Be 'rp-01'

        $null = Remove-DMReplicationPairFromConsistencyGroup -WebSession $script:session -GroupId 'rcg-01' -PairId 'rp-01' -Confirm:$false
        $script:resource | Should -Be 'DEL_MIRROR'
        $script:request.ID | Should -Be 'rcg-01'
        $script:request.RMLIST[0] | Should -Be 'rp-01'
    }

    It '<Command> calls <Resource>' -ForEach @(
        @{ Command = 'Sync-DMReplicationConsistencyGroup'; Resource = 'SYNCHRONIZE_CONSISTENCY_GROUP' }
        @{ Command = 'Split-DMReplicationConsistencyGroup'; Resource = 'SPLIT_CONSISTENCY_GROUP' }
        @{ Command = 'Switch-DMReplicationConsistencyGroup'; Resource = 'SWITCH_GROUP_ROLE' }
    ) {
        $result = & $Command -WebSession $script:session -Id 'rcg-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'rcg-01'
    }

    It 'removes a remote replication consistency group by id' {
        $result = Remove-DMReplicationConsistencyGroup -WebSession $script:session -Id 'rcg-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'CONSISTENTGROUP/rcg-01'
    }
}

Describe 'HyperMetro consistency group lifecycle commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMHyperMetroDomain { @([pscustomobject]@{ Id = 'domain-01'; Name = 'metro-domain' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = 'hmcg-01'; NAME = 'hmcg-a' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'hmcg-new'; NAME = 'hmcg-new' } }
        }
    }

    It 'creates a HyperMetro consistency group using a resolved domain name' {
        $result = New-DMHyperMetroConsistencyGroup -WebSession $script:session -Name 'hmcg-new' -DomainName 'metro-domain' `
            -RecoveryPolicy Manual -Speed Highest -Isolation $true -IsolationThresholdTime 250 -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorHyperMetroConsistencyGroup'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'HyperMetro_ConsistentGroup'
        $script:request.NAME | Should -Be 'hmcg-new'
        $script:request.DOMAINID | Should -Be 'domain-01'
        $script:request.RECOVERYPOLICY | Should -Be '2'
        $script:request.SPEED | Should -Be '4'
        $script:request.ISISOLATION | Should -BeTrue
        $script:request.ISISOLATIONTHRESHOLDTIME | Should -Be 250
    }

    It 'modifies a HyperMetro consistency group by id' {
        $result = Set-DMHyperMetroConsistencyGroup -WebSession $script:session -Id 'hmcg-01' -Speed High -Bandwidth 16 -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'HyperMetro_ConsistentGroup/hmcg-01'
        $script:request.SPEED | Should -Be '3'
        $script:request.bandwidth | Should -Be 16
    }

    It 'adds and removes a HyperMetro pair using documented association parameters' {
        $null = Add-DMHyperMetroPairToConsistencyGroup -WebSession $script:session -GroupId 'hmcg-01' -PairId 'hmp-01' -Confirm:$false
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'hyperMetro/associate/pair'
        $script:request.ID | Should -Be 'hmcg-01'
        $script:request.ASSOCIATEOBJID | Should -Be 'hmp-01'

        $null = Remove-DMHyperMetroPairFromConsistencyGroup -WebSession $script:session -GroupId 'hmcg-01' -PairId 'hmp-01' -Confirm:$false
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'hyperMetro/associate/pair?ID=hmcg-01&ASSOCIATEOBJID=hmp-01'
    }

    It '<Command> calls <Resource>' -ForEach @(
        @{ Command = 'Sync-DMHyperMetroConsistencyGroup'; Resource = 'HyperMetro_ConsistentGroup/sync' }
        @{ Command = 'Suspend-DMHyperMetroConsistencyGroup'; Resource = 'HyperMetro_ConsistentGroup/stop' }
        @{ Command = 'Start-DMHyperMetroConsistencyGroup'; Resource = 'HyperMetro_ConsistentGroup/start' }
        @{ Command = 'Switch-DMHyperMetroConsistencyGroup'; Resource = 'HyperMetro_ConsistentGroup/switch' }
    ) {
        $result = & $Command -WebSession $script:session -Id 'hmcg-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'hmcg-01'
    }

    It 'removes a HyperMetro consistency group by id' {
        $result = Remove-DMHyperMetroConsistencyGroup -WebSession $script:session -Id 'hmcg-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'HyperMetro_ConsistentGroup/hmcg-01'
    }
}
}
