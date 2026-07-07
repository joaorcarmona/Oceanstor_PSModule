BeforeDiscovery {
    $script:nasDrModule = New-Module -Name NasDrLifecycleTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource, [hashtable]$BodyData)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Resolve-DMDrPairHelper.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorVStorePair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorFileHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMVStorePair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMVStorePair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMVStorePair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Sync-DMVStorePair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Split-DMVStorePair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Switch-DMVStorePair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMFileSystemReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Enable-DMFileSystemReplicationPairSecondaryProtection.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Disable-DMFileSystemReplicationPairSecondaryProtection.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMFileSystemReplicationPairSecondaryReadOnly.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMFileHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMFileHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMFileHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Start-DMFileHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Join-DMFileHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Split-DMFileHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Switch-DMFileHyperMetroDomain.ps1"

        Export-ModuleMember -Function '*-DM*', 'Join-DMFileHyperMetroDomain'
    }

    Import-Module $script:nasDrModule -Force
}

AfterAll {
    Remove-Module -Name NasDrLifecycleTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NasDrLifecycleTestModule {
Describe 'NAS vStore pair wrappers' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                $data = if ($Resource -like 'vstore_pair/*') {
                    [pscustomobject]@{ ID = 'vsp-01'; REPTYPE = '2'; LOCALVSTORENAME = 'local-vs'; REMOTEVSTORENAME = 'remote-vs'; RUNNINGSTATUS = '1'; LINKSTATUS = '1'; CONFIGSTATUS = '0' }
                }
                else {
                    @([pscustomobject]@{ ID = 'vsp-01'; REPTYPE = '2'; LOCALVSTORENAME = 'local-vs'; REMOTEVSTORENAME = 'remote-vs'; RUNNINGSTATUS = '1'; LINKSTATUS = '1'; CONFIGSTATUS = '0' })
                }
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $data }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'vsp-new'; REPTYPE = $BodyData.REPTYPE; LOCALVSTOREID = $BodyData.LOCALVSTOREID; REMOTEVSTOREID = $BodyData.REMOTEVSTOREID } }
        }
    }

    It 'gets remote replication vStore pairs with the documented filter' {
        $result = @(Get-DMVStorePair -WebSession $script:session -ReplicationType RemoteReplication)

        $result[0].GetType().Name | Should -Be 'OceanstorVStorePair'
        $result[0].'Replication Type' | Should -Be 'RemoteReplication'
        $script:resource | Should -BeLike 'vstore_pair?filter=REPTYPE::2&range=*'
    }

    It 'creates a remote replication vStore pair' {
        $result = New-DMVStorePair -WebSession $script:session -LocalVStoreId '1' -RemoteVStoreId '2' `
            -ReplicationType RemoteReplication -RemoteDeviceId '0' -SynchronizeNetwork $true -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorVStorePair'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'vstore_pair'
        $script:request.REPTYPE | Should -Be '2'
        $script:request.REMOTEDEVICEID | Should -Be '0'
        $script:request.isNetworkSync | Should -BeTrue
    }

    It '<Command> calls <Resource>' -ForEach @(
        @{ Command = 'Sync-DMVStorePair'; Resource = 'VSTORE_PAIR/sync' }
        @{ Command = 'Split-DMVStorePair'; Resource = 'VSTORE_PAIR/split' }
        @{ Command = 'Switch-DMVStorePair'; Resource = 'VSTORE_PAIR/swap' }
    ) {
        $result = & $Command -WebSession $script:session -Id 'vsp-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'vsp-01'
    }

    It 'removes a vStore pair with the local-delete query flag' {
        $result = Remove-DMVStorePair -WebSession $script:session -Id 'vsp-01' -LocalDelete $true -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'vstore_pair/vsp-01?ISLOCALDELETEDONLY=true'
    }
}

Describe 'file-system remote replication wrappers' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'fsrp-01'; LOCALRESTYPE = '40'; LOCALRESNAME = 'local-fs'; REMOTERESNAME = 'remote-fs' } }
        }
    }

    It 'creates a file-system replication pair with LOCALRESTYPE 40' {
        $result = New-DMFileSystemReplicationPair -WebSession $script:session -LocalFileSystemId 'fs-01' `
            -RemoteDeviceId '0' -RemoteFileSystemId 'rfs-01' -VStorePairId 'vsp-01' -VstoreId '7' -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorReplicationPair'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'REPLICATIONPAIR'
        $script:request.LOCALRESTYPE | Should -Be 40
        $script:request.VSTOREPAIRID | Should -Be 'vsp-01'
        $script:request.vstoreId | Should -Be '7'
    }

    It '<Command> calls <Resource>' -ForEach @(
        @{ Command = 'Enable-DMFileSystemReplicationPairSecondaryProtection'; Resource = 'REPLICATIONPAIR/SET_SECONDARY_WRITE_LOCK' }
        @{ Command = 'Disable-DMFileSystemReplicationPairSecondaryProtection'; Resource = 'REPLICATIONPAIR/CANCEL_SECONDARY_WRITE_LOCK' }
        @{ Command = 'Set-DMFileSystemReplicationPairSecondaryReadOnly'; Resource = 'REPLICATIONPAIR/SET_SECONDARY_FILESYSTEM_READ_ONLY' }
    ) {
        $result = & $Command -WebSession $script:session -Id 'fsrp-01' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'fsrp-01'
        $script:request.vstoreId | Should -Be '7'
    }
}

Describe 'file HyperMetro domain wrappers' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                $data = if ($Resource -like 'FsHyperMetroDomain/*') {
                    [pscustomobject]@{ ID = 'fshm-01'; NAME = 'fs-domain'; RUNNINGSTATUS = '3'; SERVICESTATUS = '0'; CPTYPE = '3' }
                }
                else {
                    @([pscustomobject]@{ ID = 'fshm-01'; NAME = 'fs-domain'; RUNNINGSTATUS = '3'; SERVICESTATUS = '0'; CPTYPE = '3' })
                }
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $data }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'fshm-01'; NAME = 'fs-domain'; RUNNINGSTATUS = '1' } }
        }
    }

    It 'gets file HyperMetro domains from FsHyperMetroDomain' {
        $result = @(Get-DMFileHyperMetroDomain -WebSession $script:session)

        $result[0].GetType().Name | Should -Be 'OceanstorFileHyperMetroDomain'
        $result[0].'Running Status' | Should -Be 'Split'
        $script:resource | Should -BeLike 'FsHyperMetroDomain?range=*'
    }

    It 'creates a file HyperMetro domain' {
        $remoteDevice = [pscustomobject]@{ devId = '0'; devESN = 'SN001'; devName = 'remote-a' }
        $result = New-DMFileHyperMetroDomain -WebSession $script:session -Name 'fs-domain' `
            -RemoteDevices @($remoteDevice) -WorkMode ActiveActive -SynchronizeNetwork $true -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorFileHyperMetroDomain'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'FsHyperMetroDomain'
        $script:request.NAME | Should -Be 'fs-domain'
        $script:request.REMOTEDEVICES[0].devId | Should -Be '0'
        $script:request.workMode | Should -Be '0'
    }

    It '<Command> calls <Resource> using POST' -ForEach @(
        @{ Command = 'Start-DMFileHyperMetroDomain'; Resource = 'StartFsHyperMetroDomain' }
        @{ Command = 'Join-DMFileHyperMetroDomain'; Resource = 'JoinFsHyperMetroDomain' }
        @{ Command = 'Split-DMFileHyperMetroDomain'; Resource = 'SplitFsHyperMetroDomain' }
        @{ Command = 'Switch-DMFileHyperMetroDomain'; Resource = 'SwapRoleFsHyperMetroDomain' }
    ) {
        $result = & $Command -WebSession $script:session -Id 'fshm-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be 'fshm-01'
    }

    It 'removes a file HyperMetro domain with documented flags' {
        $result = Remove-DMFileHyperMetroDomain -WebSession $script:session -Id 'fshm-01' -LocalDelete $true -ForceDelete $true -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'FsHyperMetroDomain/fshm-01?ISLOCALDELETE=true&ISFORCEDELETE=true'
    }
}
}
