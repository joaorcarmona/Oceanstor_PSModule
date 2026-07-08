BeforeDiscovery {
    # Loads every DR mutator (replication, HyperMetro, vStore pair, file-system
    # replication) behind a stub Invoke-DeviceManager that records only mutating
    # requests. The shared Assert-DMWhatIfMakesNoApiCall helper then proves that
    # -WhatIf sends no mutating request for any of them. One -ForEach case table
    # drives all ~52 mutators so coverage stays in lockstep with the surface.
    $script:drWhatIfModule = New-Module -Name DrWhatIfTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        $moduleRoot = Resolve-Path "$testRoot\..\..\..\POSH-Oceanstor"

        # Load only the DR classes. PowerShell caches class types globally by
        # name (first definition wins), so loading every class here would let
        # this module's copy of, e.g., OceanStorLunGroup shadow another suite's
        # copy and make that suite's class methods resolve commands in this
        # module. Restricting to DR classes keeps the shadow inside the DR
        # domain, where every suite shares the same definitions.
        . (Join-Path $moduleRoot 'Private\class-OceanstorSession.ps1')
        Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Private') -Filter 'class-*.ps1' |
            Where-Object { $_.Name -match 'Replication|HyperMetro|VStorePair|RemoteDevice|RemoteLun|QuorumServer' } |
            ForEach-Object { . $_.FullName }

        Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Private') -Filter '*.ps1' |
            Where-Object { $_.Name -notlike 'class-*' -and $_.Name -ne 'Invoke-DeviceManager.ps1' } |
            ForEach-Object { . $_.FullName }

        # Stub the transport. Only POST/PUT/DELETE are recorded as mutating; GET
        # is answered with a benign empty payload so any read-only resolution a
        # cmdlet performs before ShouldProcess does not register as a mutation.
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [int]$TimeoutSec,
                [switch]$ApiV2
            )
            if ($Method -in 'POST', 'PUT', 'DELETE') {
                $script:lastRequest = [pscustomobject]@{ Method = $Method; Resource = $Resource; Body = $BodyData }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
        }

        # Load only the DR public surface. Loading every public cmdlet would
        # define Get-DMlun (and the LUN-group cmdlets) inside this dynamic
        # module; an unqualified call inside another suite's class method could
        # then resolve here instead of to that suite's mock (the documented
        # Pester cross-module class-resolution race). The WhatIf cases pass ids,
        # so no name-resolution getter is needed.
        Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Public') -Filter '*.ps1' |
            Where-Object { $_.Name -match 'Replication|HyperMetro|VStorePair' } |
            ForEach-Object { . $_.FullName }

        . (Join-Path $testRoot '..\Support\Assert-DMWhatIfSafe.ps1')

        Export-ModuleMember -Function '*-DM*', 'Assert-DMWhatIfMakesNoApiCall'
    }

    Import-Module $script:drWhatIfModule -Force
}

AfterAll {
    Remove-Module -Name DrWhatIfTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope DrWhatIfTestModule {
    # ExpectConfirmImpactHigh: New-* creators use the default impact; every
    # in-place modify / remove / lifecycle transition must declare High.
    $script:drWhatIfCases = @(
        # --- Replication pairs ---
        @{ Command = 'New-DMReplicationPair'; ExpectConfirmImpactHigh = $false; Parameters = @{ LocalLunId = 'lun-01'; RemoteDeviceId = 'rd-01'; RemoteLunId = 'rlun-01' } }
        @{ Command = 'Set-DMReplicationPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rp-01'; Speed = 'High' } }
        @{ Command = 'Remove-DMReplicationPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rp-01' } }
        @{ Command = 'Sync-DMReplicationPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rp-01' } }
        @{ Command = 'Split-DMReplicationPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rp-01' } }
        @{ Command = 'Switch-DMReplicationPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rp-01' } }
        @{ Command = 'Set-DMReplicationPairMode'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rp-01'; ReplicationMode = 'Sync' } }
        @{ Command = 'Enable-DMReplicationPairSecondaryProtection'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rp-01' } }
        @{ Command = 'Disable-DMReplicationPairSecondaryProtection'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rp-01' } }
        # --- Replication consistency groups ---
        @{ Command = 'New-DMReplicationConsistencyGroup'; ExpectConfirmImpactHigh = $false; Parameters = @{ Name = 'rep-cg' } }
        @{ Command = 'Set-DMReplicationConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rcg-01'; Description = 'whatif-test' } }
        @{ Command = 'Remove-DMReplicationConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rcg-01' } }
        @{ Command = 'Add-DMReplicationPairToConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ GroupId = 'rcg-01'; PairId = 'rp-01' } }
        @{ Command = 'Remove-DMReplicationPairFromConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ GroupId = 'rcg-01'; PairId = 'rp-01' } }
        @{ Command = 'Sync-DMReplicationConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rcg-01' } }
        @{ Command = 'Split-DMReplicationConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rcg-01' } }
        @{ Command = 'Switch-DMReplicationConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'rcg-01' } }
        # --- HyperMetro pairs ---
        @{ Command = 'New-DMHyperMetroPair'; ExpectConfirmImpactHigh = $false; Parameters = @{ DomainId = 'domain-01'; LocalLunId = 'lun-01'; RemoteLunId = 'rlun-01' } }
        @{ Command = 'Set-DMHyperMetroPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmp-01'; Speed = 'High' } }
        @{ Command = 'Remove-DMHyperMetroPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmp-01' } }
        @{ Command = 'Sync-DMHyperMetroPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmp-01' } }
        @{ Command = 'Suspend-DMHyperMetroPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmp-01' } }
        @{ Command = 'Start-DMHyperMetroPair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmp-01' } }
        @{ Command = 'Switch-DMHyperMetroPairPriority'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmp-01' } }
        @{ Command = 'Set-DMHyperMetroPairPreferredPolicy'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmp-01'; PreferredSitePolicy = 'ServiceBased' } }
        # --- HyperMetro consistency groups ---
        @{ Command = 'New-DMHyperMetroConsistencyGroup'; ExpectConfirmImpactHigh = $false; Parameters = @{ Name = 'metro-cg'; DomainId = 'domain-01' } }
        @{ Command = 'Set-DMHyperMetroConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmcg-01'; Description = 'whatif-test' } }
        @{ Command = 'Remove-DMHyperMetroConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmcg-01' } }
        @{ Command = 'Add-DMHyperMetroPairToConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ GroupId = 'hmcg-01'; PairId = 'hmp-01' } }
        @{ Command = 'Remove-DMHyperMetroPairFromConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ GroupId = 'hmcg-01'; PairId = 'hmp-01' } }
        @{ Command = 'Sync-DMHyperMetroConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmcg-01' } }
        @{ Command = 'Suspend-DMHyperMetroConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmcg-01' } }
        @{ Command = 'Start-DMHyperMetroConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmcg-01' } }
        @{ Command = 'Switch-DMHyperMetroConsistencyGroup'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'hmcg-01' } }
        # --- HyperMetro domains ---
        @{ Command = 'New-DMHyperMetroDomain'; ExpectConfirmImpactHigh = $false; Parameters = @{ Name = 'metro-domain'; RemoteDevices = @('rd-01') } }
        @{ Command = 'Set-DMHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'domain-01'; Description = 'whatif-test' } }
        @{ Command = 'Remove-DMHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'domain-01' } }
        @{ Command = 'Add-DMQuorumServerToHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'domain-01'; QuorumServerId = 'q-01' } }
        @{ Command = 'Remove-DMQuorumServerFromHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'domain-01'; QuorumServerId = 'q-01' } }
        # --- File HyperMetro domains ---
        @{ Command = 'New-DMFileHyperMetroDomain'; ExpectConfirmImpactHigh = $false; Parameters = @{ Name = 'file-domain'; RemoteDevices = @('rd-01') } }
        @{ Command = 'Join-DMFileHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'fdom-01' } }
        @{ Command = 'Split-DMFileHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'fdom-01' } }
        @{ Command = 'Start-DMFileHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'fdom-01' } }
        @{ Command = 'Switch-DMFileHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'fdom-01' } }
        @{ Command = 'Remove-DMFileHyperMetroDomain'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'fdom-01' } }
        # --- vStore pairs ---
        @{ Command = 'New-DMVStorePair'; ExpectConfirmImpactHigh = $false; Parameters = @{ LocalVStoreId = 'lv-01'; RemoteVStoreId = 'rv-01'; ReplicationType = 'HyperMetro'; DomainId = 'domain-01' } }
        @{ Command = 'Remove-DMVStorePair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'vp-01' } }
        @{ Command = 'Sync-DMVStorePair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'vp-01' } }
        @{ Command = 'Split-DMVStorePair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'vp-01' } }
        @{ Command = 'Switch-DMVStorePair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'vp-01' } }
        @{ Command = 'Set-DMVStorePair'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'vp-01'; IpWorkMode = 'LoadBalancing' } }
        # --- File-system replication pairs ---
        @{ Command = 'New-DMFileSystemReplicationPair'; ExpectConfirmImpactHigh = $false; Parameters = @{ LocalFileSystemId = 'fs-01'; RemoteDeviceId = 'rd-01'; RemoteFileSystemId = 'rfs-01' } }
        @{ Command = 'Enable-DMFileSystemReplicationPairSecondaryProtection'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'fsrp-01' } }
        @{ Command = 'Disable-DMFileSystemReplicationPairSecondaryProtection'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'fsrp-01' } }
        @{ Command = 'Set-DMFileSystemReplicationPairSecondaryReadOnly'; ExpectConfirmImpactHigh = $true; Parameters = @{ Id = 'fsrp-01' } }
    )

    Describe 'DR mutator -WhatIf safety' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001'; hostname = 'array.example' }
            $script:lastRequest = $null
        }

        It '<Command> sends no mutating request under -WhatIf' -ForEach $script:drWhatIfCases {
            $invokeParameters = @{ WebSession = $script:session } + $Parameters

            Assert-DMWhatIfMakesNoApiCall -Command $Command -Parameters $invokeParameters -GetCapturedRequest { $script:lastRequest }
        }

        It '<Command> declares ConfirmImpact High for in-place modify/remove/transition' -ForEach ($script:drWhatIfCases | Where-Object { $_.ExpectConfirmImpactHigh } | Sort-Object { $_.Command } -Unique) {
            $binding = (Get-Command -Name $Command).ScriptBlock.Attributes |
                Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

            $binding.ConfirmImpact | Should -Be 'High'
        }
    }
}
