$script:ReplicationMutationWorkflow = {
        $replicationCommandNames = @(
            'Get-DMRemoteDevice', 'Get-DMRemoteLun',
            'New-DMReplicationPair', 'Get-DMReplicationPair', 'Sync-DMReplicationPair',
            'Split-DMReplicationPair', 'Switch-DMReplicationPair', 'Remove-DMReplicationPair',
            'New-DMReplicationConsistencyGroup', 'Get-DMReplicationConsistencyGroup',
            'Set-DMReplicationConsistencyGroup', 'Add-DMReplicationPairToConsistencyGroup',
            'Remove-DMReplicationPairFromConsistencyGroup', 'Sync-DMReplicationConsistencyGroup',
            'Split-DMReplicationConsistencyGroup', 'Switch-DMReplicationConsistencyGroup',
            'Remove-DMReplicationConsistencyGroup'
        )

        if (-not $configuration.Replication.Enabled) {
            Add-SkippedResult -Name $replicationCommandNames -Status 'NotConfigured' `
                -Reason 'Set Replication.Enabled and Replication.AllowDrMutation to true with remote device and remote LUN configuration to run the DR replication workflow.'
            return
        }

        if (-not $owned.Lun.Contains($lunName)) {
            Add-SkippedResult -Name $replicationCommandNames -Status 'Blocked' `
                -Reason 'Replication validation requires the test-owned local LUN created by the LUN workflow.'
            return
        }

        $replicationPairName = New-TestName -Suffix 'rpair'
        $replicationGroupName = New-TestName -Suffix 'rcg'
        $replicationPairId = $null
        $replicationGroupId = $null
        $replicationPairInGroup = $false

        $remoteDeviceId = if ($configuration.Replication.RemoteDeviceId) {
            $configuration.Replication.RemoteDeviceId
        }
        else {
            $remoteDevice = @(Add-MutationReadVerification -Name 'Get-DMRemoteDevice:Replication' -ExpectedType 'OceanstorRemoteDevice' -Action {
                Get-DMRemoteDevice -WebSession $session -Name $configuration.Replication.RemoteDeviceName |
                    Where-Object Name -EQ $configuration.Replication.RemoteDeviceName
            })
            if ($remoteDevice.Count -eq 0) { return }
            $remoteDevice[0].Id
        }

        $remoteLunId = if ($configuration.Replication.RemoteLunId) {
            $configuration.Replication.RemoteLunId
        }
        else {
            $remoteLun = @(Add-MutationReadVerification -Name 'Get-DMRemoteLun:Replication' -ExpectedType 'OceanstorRemoteLun' -Action {
                Get-DMRemoteLun -WebSession $session -RemoteDeviceId $remoteDeviceId `
                    -RemoteServiceType $configuration.Replication.RemoteServiceType -Name $configuration.Replication.RemoteLunName |
                    Where-Object Name -EQ $configuration.Replication.RemoteLunName
            })
            if ($remoteLun.Count -eq 0) { return }
            $remoteLun[0].'Remote Lun Id'
        }

        $replicationPair = @(Invoke-MutationStep -Name 'New-DMReplicationPair' -ExpectedType 'OceanstorReplicationPair' -Action {
            Assert-TestOwnedResource -Kind Lun -Identity $lunName
            New-DMReplicationPair -WebSession $session -LocalLunId $lunId -RemoteDeviceId $remoteDeviceId `
                -RemoteLunId $remoteLunId -ReplicationMode Async -SynchronizationType Manual `
                -RecoveryPolicy Manual -Speed Low -InitialSyncType AllData
        })
        if ($replicationPair.Count -gt 0) {
            $replicationPairId = $replicationPair[0].Id
            Register-TestOwnedResource -Kind ReplicationPair -Identity $replicationPairId
            Register-CleanupAction -Name 'Remove-DMReplicationPair' -Action {
                Invoke-OwnedRemoval -Name 'Remove-DMReplicationPair' -Kind ReplicationPair -Identity $replicationPairId -Action {
                    Remove-DMReplicationPair -WebSession $session -Id $replicationPairId -Confirm:$false
                }
            }
        }

        if ($owned.ReplicationPair.Contains($replicationPairId)) {
            Add-MutationReadVerification -Name 'Get-DMReplicationPair:Created' -ExpectedType 'OceanstorReplicationPair' -Action {
                Get-DMReplicationPair -WebSession $session -Id $replicationPairId
            } | Out-Null

            Invoke-MutationStep -Name 'Sync-DMReplicationPair' -Action {
                Assert-TestOwnedResource -Kind ReplicationPair -Identity $replicationPairId
                Sync-DMReplicationPair -WebSession $session -Id $replicationPairId -Confirm:$false
            } | Out-Null

            Invoke-MutationStep -Name 'Split-DMReplicationPair' -Action {
                Assert-TestOwnedResource -Kind ReplicationPair -Identity $replicationPairId
                Split-DMReplicationPair -WebSession $session -Id $replicationPairId -Confirm:$false
            } | Out-Null

            if ($configuration.Replication.AllowFailover) {
                Invoke-MutationStep -Name 'Switch-DMReplicationPair' -Action {
                    Assert-TestOwnedResource -Kind ReplicationPair -Identity $replicationPairId
                    Switch-DMReplicationPair -WebSession $session -Id $replicationPairId -Confirm:$false
                } | Out-Null
            }
            else {
                Add-SkippedResult -Name 'Switch-DMReplicationPair' -Status 'SkippedUnsafe' `
                    -Reason 'Set Replication.AllowFailover = $true only in a lab where primary/secondary switchover is expected.'
            }

            $replicationGroup = @(Invoke-MutationStep -Name 'New-DMReplicationConsistencyGroup' -ExpectedType 'OceanstorReplicationConsistencyGroup' -Action {
                if (@(Get-DMReplicationConsistencyGroup -WebSession $session -Name $replicationGroupName | Where-Object Name -EQ $replicationGroupName).Count -gt 0) {
                    throw "A replication consistency group named '$replicationGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMReplicationConsistencyGroup -WebSession $session -Name $replicationGroupName `
                    -RemoteDeviceId $remoteDeviceId -ReplicationMode Async -SynchronizationType Manual `
                    -RecoveryPolicy Manual -Speed Low
            })
            if ($replicationGroup.Count -gt 0 -and $replicationGroup[0].Name -eq $replicationGroupName) {
                $replicationGroupId = $replicationGroup[0].Id
                Register-TestOwnedResource -Kind ReplicationConsistencyGroup -Identity $replicationGroupId
                Register-CleanupAction -Name 'Remove-DMReplicationConsistencyGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMReplicationConsistencyGroup' -Kind ReplicationConsistencyGroup -Identity $replicationGroupId -Action {
                        Remove-DMReplicationConsistencyGroup -WebSession $session -Id $replicationGroupId -Confirm:$false
                    }
                }
            }
        }

        if ($owned.ReplicationConsistencyGroup.Contains($replicationGroupId)) {
            Invoke-MutationStep -Name 'Set-DMReplicationConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind ReplicationConsistencyGroup -Identity $replicationGroupId
                Set-DMReplicationConsistencyGroup -WebSession $session -Id $replicationGroupId `
                    -Description "Integrity validation updated $runId" -Confirm:$false
            } | Out-Null

            Invoke-MutationStep -Name 'Add-DMReplicationPairToConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind ReplicationConsistencyGroup -Identity $replicationGroupId
                Assert-TestOwnedResource -Kind ReplicationPair -Identity $replicationPairId
                Add-DMReplicationPairToConsistencyGroup -WebSession $session -GroupId $replicationGroupId `
                    -PairId $replicationPairId -Confirm:$false
            } | Out-Null
            $replicationPairInGroup = $true
            Register-CleanupAction -Name 'Remove-DMReplicationPairFromConsistencyGroup:Cleanup' -Action {
                if ($replicationPairInGroup -and $owned.ReplicationConsistencyGroup.Contains($replicationGroupId) -and $owned.ReplicationPair.Contains($replicationPairId)) {
                    Invoke-MutationStep -Name 'Remove-DMReplicationPairFromConsistencyGroup:Cleanup' -Action {
                        Remove-DMReplicationPairFromConsistencyGroup -WebSession $session -GroupId $replicationGroupId `
                            -PairId $replicationPairId -Confirm:$false
                    } | Out-Null
                }
            }

            Add-MutationReadVerification -Name 'Get-DMReplicationConsistencyGroup:Created' -ExpectedType 'OceanstorReplicationConsistencyGroup' -Action {
                Get-DMReplicationConsistencyGroup -WebSession $session -Id $replicationGroupId
            } | Out-Null

            Invoke-MutationStep -Name 'Sync-DMReplicationConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind ReplicationConsistencyGroup -Identity $replicationGroupId
                Sync-DMReplicationConsistencyGroup -WebSession $session -Id $replicationGroupId -Confirm:$false
            } | Out-Null

            Invoke-MutationStep -Name 'Split-DMReplicationConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind ReplicationConsistencyGroup -Identity $replicationGroupId
                Split-DMReplicationConsistencyGroup -WebSession $session -Id $replicationGroupId -Confirm:$false
            } | Out-Null

            if ($configuration.Replication.AllowFailover) {
                Invoke-MutationStep -Name 'Switch-DMReplicationConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind ReplicationConsistencyGroup -Identity $replicationGroupId
                    Switch-DMReplicationConsistencyGroup -WebSession $session -Id $replicationGroupId -Confirm:$false
                } | Out-Null
            }
            else {
                Add-SkippedResult -Name 'Switch-DMReplicationConsistencyGroup' -Status 'SkippedUnsafe' `
                    -Reason 'Set Replication.AllowFailover = $true only in a lab where consistency group switchover is expected.'
            }

            Invoke-MutationStep -Name 'Remove-DMReplicationPairFromConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind ReplicationConsistencyGroup -Identity $replicationGroupId
                Assert-TestOwnedResource -Kind ReplicationPair -Identity $replicationPairId
                Remove-DMReplicationPairFromConsistencyGroup -WebSession $session -GroupId $replicationGroupId `
                    -PairId $replicationPairId -Confirm:$false
            } | Out-Null
            $replicationPairInGroup = $false
        }

}
