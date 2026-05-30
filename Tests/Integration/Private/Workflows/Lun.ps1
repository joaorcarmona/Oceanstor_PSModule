$script:LunMutationWorkflow = {
        if ($configuration.Lun.Enabled) {
            $lun = @(Invoke-MutationStep -Name 'new-DMLun' -Action {
                if (@(get-DMluns -WebSession $session | Where-Object Name -EQ $lunName).Count -gt 0) {
                    throw "A LUN named '$lunName' already exists; refusing to claim it as test-owned."
                }
                new-DMLun -WebSession $session -LunName $lunName -Capacity $configuration.Lun.CapacityMB `
                    -StoragePoolID $configuration.StoragePoolId -AllocType $configuration.Lun.AllocationType `
                    -Description "Integrity validation run $runId"
            })
            if ($lun.Count -gt 0 -and $lun[0].Name -eq $lunName) {
                Register-TestOwnedResource -Kind Lun -Identity $lunName
                Register-CleanupAction -Name 'Remove-DMLun' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMLun' -Kind Lun -Identity $lunName -Action {
                        Remove-DMLun -WebSession $session -LunName $lunName -ImmediateDelete -Confirm:$false
                    }
                }
            }

            if ($owned.Lun.Contains($lunName)) {
                $snapshot = @(Invoke-MutationStep -Name 'new-DMLunSnapshot' -ExpectedType 'OceanstorLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    if (@(get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $snapshotName).Count -gt 0) {
                        throw "A LUN snapshot named '$snapshotName' already exists; refusing to claim it as test-owned."
                    }
                    new-DMLunSnapshot -WebSession $session -SnapshotName $snapshotName -SourceLunName $lunName `
                        -Description "Integrity validation run $runId"
                })
                if ($snapshot.Count -gt 0 -and $snapshot[0].Name -eq $snapshotName) {
                    Register-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Register-CleanupAction -Name 'remove-DMLunSnapShot' -Action {
                        Invoke-OwnedRemoval -Name 'remove-DMLunSnapShot' -Kind LunSnapshot -Identity $snapshotName -Action {
                            remove-DMLunSnapShot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                        }
                    }
                }
            }

            if ($owned.LunSnapshot.Contains($snapshotName)) {
                $copy = @(Invoke-MutationStep -Name 'new-DMLunSnapshotCopy' -ExpectedType 'OceanstorLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    if (@(get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $snapshotCopyName).Count -gt 0) {
                        throw "A LUN snapshot named '$snapshotCopyName' already exists; refusing to claim it as test-owned."
                    }
                    new-DMLunSnapshotCopy -WebSession $session -SourceSnapShotName $snapshotName `
                        -SnapshotCopyName $snapshotCopyName -Description "Integrity validation run $runId"
                })
                if ($copy.Count -gt 0 -and $copy[0].Name -eq $snapshotCopyName) {
                    Register-TestOwnedResource -Kind LunSnapshot -Identity $snapshotCopyName
                    Register-CleanupAction -Name 'remove-DMLunSnapShot:Copy' -Action {
                        Invoke-OwnedRemoval -Name 'remove-DMLunSnapShot:Copy' -Kind LunSnapshot -Identity $snapshotCopyName -Action {
                            remove-DMLunSnapShot -WebSession $session -SnapShotName $snapshotCopyName -Confirm:$false
                        }
                    }
                }

                Invoke-MutationStep -Name 'Enable-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Enable-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Restart-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Restart-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Restore-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Restore-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                } | Out-Null
                $expandedSnapshotCapacity = if ($configuration.Lun.ExpandedSnapshotCapacitySectors -gt 0) {
                    [uint64]$configuration.Lun.ExpandedSnapshotCapacitySectors
                }
                else {
                    [uint64]$snapshot[0].'User Capacity' + 2048
                }
                Invoke-MutationStep -Name 'Resize-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Resize-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName `
                        -UserCapacity $expandedSnapshotCapacity -Confirm:$false
                } | Out-Null
            }

        }
        else {
            Add-SkippedResult -Name @(
                'new-DMLun', 'new-DMLunSnapshot', 'new-DMLunSnapshotCopy', 'Enable-DMLunSnapshot',
                'Restart-DMLunSnapshot', 'Resize-DMLunSnapshot', 'Restore-DMLunSnapshot',
                'remove-DMLunSnapShot', 'Remove-DMLun'
            ) -Status 'NotConfigured' -Reason 'Set Lun.Enabled = $true and provide StoragePoolId to run the test-owned LUN workflow.'
        }

}
