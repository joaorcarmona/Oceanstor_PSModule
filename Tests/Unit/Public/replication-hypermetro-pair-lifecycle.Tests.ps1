BeforeDiscovery {
    $script:drPairModule = New-Module -Name DrPairLifecycleTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource, [hashtable]$BodyData)
        }
        function Get-DMlun { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMRemoteLun { param([pscustomobject]$WebSession, [string]$RemoteDeviceId, [string]$RemoteServiceType, [string]$Name) }
        function Get-DMHyperMetroDomain { param([pscustomobject]$WebSession, [string]$Name) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Resolve-DMDrPairHelper.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Sync-DMReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Split-DMReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Switch-DMReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Enable-DMReplicationPairSecondaryProtection.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Disable-DMReplicationPairSecondaryProtection.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Sync-DMHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Suspend-DMHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Start-DMHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Switch-DMHyperMetroPairPriority.ps1"

        Export-ModuleMember -Function '*-DM*'
    }

    Import-Module $script:drPairModule -Force
}

AfterAll {
    Remove-Module -Name DrPairLifecycleTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope DrPairLifecycleTestModule {
Describe 'Replication pair lifecycle commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlun { @([pscustomobject]@{ Id = 'lun-01'; Name = 'local-lun' }) }
        Mock Get-DMRemoteLun { @([pscustomobject]@{ Id = 'remote-lun-row'; Name = 'remote-lun'; 'Remote Lun Id' = 'rlun-01' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = 'rp-01'; LOCALRESNAME = 'local-lun'; REMOTERESNAME = 'remote-lun' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'rp-new'; LOCALRESNAME = 'local-lun'; REMOTERESNAME = 'remote-lun' } }
        }
    }

    It 'creates a replication pair using resolved local and remote LUN names' {
        $result = New-DMReplicationPair -WebSession $script:session -LocalLunName 'local-lun' -RemoteDeviceId 'remote-01' `
            -RemoteLunName 'remote-lun' -ReplicationMode Sync -SynchronizationType Manual -RecoveryPolicy Manual -Speed High -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorReplicationPair'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'REPLICATIONPAIR'
        $script:request.LOCALRESID | Should -Be 'lun-01'
        $script:request.REMOTEDEVICEID | Should -Be 'remote-01'
        $script:request.REMOTERESID | Should -Be 'rlun-01'
        $script:request.REPLICATIONMODEL | Should -Be '1'
        $script:request.RECOVERYPOLICY | Should -Be '2'
        $script:request.SPEED | Should -Be '3'
    }

    It 'does not create a replication pair under WhatIf' {
        $null = New-DMReplicationPair -WebSession $script:session -LocalLunId 'lun-01' -RemoteDeviceId 'remote-01' -RemoteLunId 'rlun-01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter { $Method -eq 'POST' }
    }

    It 'modifies a replication pair by id' {
        $result = Set-DMReplicationPair -WebSession $script:session -Id 'rp-01' -Speed Highest -RecoveryPolicy Automatic -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'REPLICATIONPAIR/rp-01'
        $script:request.SPEED | Should -Be '4'
        $script:request.RECOVERYPOLICY | Should -Be '1'
    }

    It '<Command> calls <Resource>' -ForEach @(
        @{ Command = 'Sync-DMReplicationPair'; Resource = 'REPLICATIONPAIR/sync' }
        @{ Command = 'Split-DMReplicationPair'; Resource = 'REPLICATIONPAIR/split' }
        @{ Command = 'Switch-DMReplicationPair'; Resource = 'REPLICATIONPAIR/switch' }
    ) {
        $result = & $Command -WebSession $script:session -Id 'rp-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'rp-01'
    }

    It 'enables and disables secondary protection with documented SECRESACCESS values' {
        $null = Enable-DMReplicationPairSecondaryProtection -WebSession $script:session -Id 'rp-01' -Confirm:$false
        $script:request.SECRESACCESS | Should -Be '2'

        $null = Disable-DMReplicationPairSecondaryProtection -WebSession $script:session -Id 'rp-01' -Confirm:$false
        $script:request.SECRESACCESS | Should -Be '3'
        $script:resource | Should -Be 'REPLICATIONPAIR/rp-01'
    }

    It 'removes a replication pair by id' {
        $result = Remove-DMReplicationPair -WebSession $script:session -Id 'rp-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'REPLICATIONPAIR/rp-01'
    }
}

Describe 'HyperMetro pair lifecycle commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlun { @([pscustomobject]@{ Id = 'lun-01'; Name = 'local-lun' }) }
        Mock Get-DMRemoteLun { @([pscustomobject]@{ Id = 'remote-lun-row'; Name = 'remote-lun'; 'Remote Lun Id' = 'rlun-01' }) }
        Mock Get-DMHyperMetroDomain { @([pscustomobject]@{ Id = 'domain-01'; Name = 'metro-domain' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = 'hmp-01'; LOCALOBJNAME = 'local-lun'; REMOTEOBJNAME = 'remote-lun' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'hmp-new'; LOCALOBJNAME = 'local-lun'; REMOTEOBJNAME = 'remote-lun' } }
        }
    }

    It 'creates a HyperMetro pair using resolved names' {
        $result = New-DMHyperMetroPair -WebSession $script:session -DomainName 'metro-domain' -LocalLunName 'local-lun' `
            -RemoteDeviceId 'remote-01' -RemoteLunName 'remote-lun' -FirstSync -RecoveryPolicy Manual -Speed Highest -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorHyperMetroPair'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'HyperMetroPair'
        $script:request.DOMAINID | Should -Be 'domain-01'
        $script:request.HCRESOURCETYPE | Should -Be 1
        $script:request.LOCALOBJID | Should -Be 'lun-01'
        $script:request.REMOTEOBJID | Should -Be 'rlun-01'
        $script:request.ISFIRSTSYNC | Should -BeTrue
        $script:request.SPEED | Should -Be '4'
    }

    It 'modifies a HyperMetro pair by id' {
        $result = Set-DMHyperMetroPair -WebSession $script:session -Id 'hmp-01' -Speed High -Isolation $true -Confirm:$false

        $result.Code | Should -Be 0
        $script:resource | Should -Be 'HyperMetroPair/hmp-01'
        $script:request.SPEED | Should -Be '3'
        $script:request.isIsolation | Should -BeTrue
    }

    It '<Command> calls <Resource>' -ForEach @(
        @{ Command = 'Sync-DMHyperMetroPair'; Resource = 'HyperMetroPair/synchronize_hcpair' }
        @{ Command = 'Suspend-DMHyperMetroPair'; Resource = 'HyperMetroPair/disable_hcpair' }
        @{ Command = 'Start-DMHyperMetroPair'; Resource = 'HyperMetroPair/startup_node' }
        @{ Command = 'Switch-DMHyperMetroPairPriority'; Resource = 'HyperMetroPair/SWAP_HCPAIR' }
    ) {
        $result = & $Command -WebSession $script:session -Id 'hmp-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'hmp-01'
    }

    It 'removes a HyperMetro pair with documented query flags' {
        $result = Remove-DMHyperMetroPair -WebSession $script:session -Id 'hmp-01' -LocalDelete $true -RefreshWwn $false -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'HyperMetroPair/hmp-01?ISLOCALDELETE=true&ISREFRESHWWN=false'
    }
}

Describe 'DR lifecycle pipeline input binds Id by property name' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                if ($Resource -like 'REPLICATIONPAIR*') {
                    return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = 'rp-77'; LOCALRESNAME = 'l'; REMOTERESNAME = 'r' }) }
                }
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = 'hmp-77'; LOCALOBJNAME = 'l'; REMOTEOBJNAME = 'r' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'ignored' } }
        }
    }

    It 'flows Get-DMReplicationPair Id into <Command>' -ForEach @(
        @{ Command = 'Sync-DMReplicationPair'; Resource = 'REPLICATIONPAIR/sync' }
        @{ Command = 'Split-DMReplicationPair'; Resource = 'REPLICATIONPAIR/split' }
        @{ Command = 'Switch-DMReplicationPair'; Resource = 'REPLICATIONPAIR/switch' }
    ) {
        Get-DMReplicationPair -WebSession $script:session | & $Command -WebSession $script:session -Confirm:$false

        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'rp-77'
    }

    It 'flows Get-DMHyperMetroPair Id into <Command>' -ForEach @(
        @{ Command = 'Sync-DMHyperMetroPair'; Resource = 'HyperMetroPair/synchronize_hcpair' }
        @{ Command = 'Suspend-DMHyperMetroPair'; Resource = 'HyperMetroPair/disable_hcpair' }
    ) {
        Get-DMHyperMetroPair -WebSession $script:session | & $Command -WebSession $script:session -Confirm:$false

        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'hmp-77'
    }
}
}
