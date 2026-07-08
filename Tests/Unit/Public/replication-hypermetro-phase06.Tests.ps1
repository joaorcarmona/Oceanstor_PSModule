BeforeDiscovery {
    # Phase 06 carry-over cmdlets: dedicated REPLICATIONPAIR/transfer and
    # HyperMetroPair/MODIFY_PREFERRED_POLICY wrappers, Set-DMVStorePair
    # (VSTORE_PAIR/change_ip_work_mode), and the file-system-filtered
    # replication-pair getter. Loaded behind a stub transport that records the
    # last request so each test can assert the exact endpoint, method and body.
    $script:phase06Module = New-Module -Name DrPhase06TestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        $moduleRoot = Resolve-Path "$testRoot\..\..\..\POSH-Oceanstor"

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [int]$TimeoutSec,
                [switch]$ApiV2
            )
            $script:lastMethod = $Method
            $script:lastResource = $Resource
            $script:lastBody = $BodyData
            if ($Method -eq 'GET') {
                # Single short page: the FS-filtered getter's paged request stops
                # after one page and yields one file-system replication pair row.
                return [pscustomobject]@{
                    error = [pscustomobject]@{ Code = 0 }
                    data  = @([pscustomobject]@{ ID = 'fsrp-01'; LOCALRESID = '42'; LOCALRESTYPE = '40'; LOCALRESNAME = 'fs-a' })
                }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
        }

        . (Join-Path $moduleRoot 'Private\Get-DMApiErrorMessage.ps1')
        . (Join-Path $moduleRoot 'Private\Assert-DMApiSuccess.ps1')
        . (Join-Path $moduleRoot 'Private\Select-DMResponseData.ps1')
        . (Join-Path $moduleRoot 'Private\Invoke-DMPagedRequest.ps1')
        . (Join-Path $moduleRoot 'Private\Resolve-DMDrPairHelper.ps1')
        . (Join-Path $moduleRoot 'Private\class-OceanstorReplicationPair.ps1')
        . (Join-Path $moduleRoot 'Private\class-OceanstorHyperMetroPair.ps1')
        . (Join-Path $moduleRoot 'Private\class-OceanstorVStorePair.ps1')

        . (Join-Path $moduleRoot 'Public\Get-DMReplicationPair.ps1')
        . (Join-Path $moduleRoot 'Public\Get-DMHyperMetroPair.ps1')
        . (Join-Path $moduleRoot 'Public\Get-DMVStorePair.ps1')
        . (Join-Path $moduleRoot 'Public\Set-DMReplicationPairMode.ps1')
        . (Join-Path $moduleRoot 'Public\Set-DMHyperMetroPairPreferredPolicy.ps1')
        . (Join-Path $moduleRoot 'Public\Set-DMVStorePair.ps1')
        . (Join-Path $moduleRoot 'Public\Get-DMFileSystemReplicationPair.ps1')

        Export-ModuleMember -Function '*-DM*'
    }

    Import-Module $script:phase06Module -Force
}

AfterAll {
    Remove-Module -Name DrPhase06TestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope DrPhase06TestModule {
  Describe 'Phase 06 DR carry-over cmdlets' {
    BeforeEach {
        $script:session = [pscustomobject]@{ Name = 'phase06-session' }
        $script:lastMethod = $null
        $script:lastResource = $null
        $script:lastBody = $null
    }

    Context 'Set-DMReplicationPairMode (REPLICATIONPAIR/transfer)' {
        It 'sends the documented transfer body for an asynchronous change' {
            $result = Set-DMReplicationPairMode -WebSession $script:session -Id 'rp-01' `
                -ReplicationMode 'Async' -SynchronizationType 'Manual' -Confirm:$false

            $result.Code | Should -Be 0
            $script:lastMethod | Should -Be 'PUT'
            $script:lastResource | Should -Be 'REPLICATIONPAIR/transfer'
            $script:lastBody.ID | Should -Be 'rp-01'
            $script:lastBody.TYPE | Should -Be 263
            $script:lastBody.REPLICATIONMODEL | Should -Be '2'
            $script:lastBody.SYNCHRONIZETYPE | Should -Be '1'
        }

        It 'requires SynchronizationType when changing to asynchronous' {
            { Set-DMReplicationPairMode -WebSession $script:session -Id 'rp-01' -ReplicationMode 'Async' -Confirm:$false } |
                Should -Throw '*SynchronizationType is required*'
        }

        It 'makes no API call under -WhatIf' {
            Set-DMReplicationPairMode -WebSession $script:session -Id 'rp-01' -ReplicationMode 'Sync' -WhatIf
            $script:lastMethod | Should -BeNullOrEmpty
        }

        It 'is a High-impact mutator and exposes no -ApiProperties passthrough' {
            $binding = (Get-Command Set-DMReplicationPairMode).ScriptBlock.Attributes |
                Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $binding.ConfirmImpact | Should -Be 'High'
            (Get-Command Set-DMReplicationPairMode).Parameters.ContainsKey('ApiProperties') | Should -BeFalse
        }
    }

    Context 'Set-DMHyperMetroPairPreferredPolicy (HyperMetroPair/MODIFY_PREFERRED_POLICY)' {
        It 'sends the documented preferred-policy body' {
            $result = Set-DMHyperMetroPairPreferredPolicy -WebSession $script:session -Id 'hmp-01' `
                -PreferredSitePolicy 'ServiceBased' -Confirm:$false

            $result.Code | Should -Be 0
            $script:lastMethod | Should -Be 'PUT'
            $script:lastResource | Should -Be 'HyperMetroPair/MODIFY_PREFERRED_POLICY'
            $script:lastBody.ID | Should -Be 'hmp-01'
            $script:lastBody.preferredSitePolicyForArbitration | Should -Be 2
        }

        It 'maps UserDefined to policy code 1' {
            Set-DMHyperMetroPairPreferredPolicy -WebSession $script:session -Id 'hmp-01' `
                -PreferredSitePolicy 'UserDefined' -Confirm:$false | Out-Null
            $script:lastBody.preferredSitePolicyForArbitration | Should -Be 1
        }

        It 'makes no API call under -WhatIf' {
            Set-DMHyperMetroPairPreferredPolicy -WebSession $script:session -Id 'hmp-01' -PreferredSitePolicy 'ServiceBased' -WhatIf
            $script:lastMethod | Should -BeNullOrEmpty
        }

        It 'is a High-impact mutator and exposes no -ApiProperties passthrough' {
            $binding = (Get-Command Set-DMHyperMetroPairPreferredPolicy).ScriptBlock.Attributes |
                Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $binding.ConfirmImpact | Should -Be 'High'
            (Get-Command Set-DMHyperMetroPairPreferredPolicy).Parameters.ContainsKey('ApiProperties') | Should -BeFalse
        }
    }

    Context 'Set-DMVStorePair (VSTORE_PAIR/change_ip_work_mode)' {
        It 'sends the documented preferred-mode body with local prefer' {
            $result = Set-DMVStorePair -WebSession $script:session -Id 'vp-01' `
                -IpWorkMode 'Preferred' -LocalPrefer 'Preferred' -Confirm:$false

            $result.Code | Should -Be 0
            $script:lastMethod | Should -Be 'PUT'
            $script:lastResource | Should -Be 'VSTORE_PAIR/change_ip_work_mode'
            $script:lastBody.ID | Should -Be 'vp-01'
            $script:lastBody.ipWorkMode | Should -Be 2
            $script:lastBody.isLocalPrefer | Should -Be 2
        }

        It 'sets isLocalChange for a single-site load-balancing change' {
            Set-DMVStorePair -WebSession $script:session -Id 'vp-01' -IpWorkMode 'LoadBalancing' -SingleSiteChange -Confirm:$false | Out-Null
            $script:lastBody.ipWorkMode | Should -Be 1
            $script:lastBody.isLocalChange | Should -BeTrue
            $script:lastBody.ContainsKey('isLocalPrefer') | Should -BeFalse
        }

        It 'requires LocalPrefer when IpWorkMode is Preferred' {
            { Set-DMVStorePair -WebSession $script:session -Id 'vp-01' -IpWorkMode 'Preferred' -Confirm:$false } |
                Should -Throw '*LocalPrefer is required*'
        }

        It 'makes no API call under -WhatIf' {
            Set-DMVStorePair -WebSession $script:session -Id 'vp-01' -IpWorkMode 'LoadBalancing' -WhatIf
            $script:lastMethod | Should -BeNullOrEmpty
        }
    }

    Context 'Get-DMFileSystemReplicationPair (server-side filter=LOCALRESID)' {
        It 'sends the server-side LOCALRESID filter and stays read-only' {
            $pairs = @(Get-DMFileSystemReplicationPair -WebSession $script:session -FileSystemId '42')

            $script:lastMethod | Should -Be 'GET'
            $script:lastResource | Should -BeLike '*filter=LOCALRESID::42*'
            $pairs.Count | Should -Be 1
            $pairs[0].GetType().Name | Should -Be 'OceanstorReplicationPair'
            $pairs[0].{Local Resource Id} | Should -Be '42'
        }
    }
  }
}
