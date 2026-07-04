$script:LunMutationWorkflow = {
        if ($configuration.Lun.Enabled) {
            $lun = @(Invoke-MutationStep -Name 'New-DMLun' -Action {
                if (@(Get-DMlun -WebSession $session -Name $lunName | Where-Object Name -EQ $lunName).Count -gt 0) {
                    throw "A LUN named '$lunName' already exists; refusing to claim it as test-owned."
                }
                New-DMLun -WebSession $session -LunName $lunName -Capacity $configuration.Lun.CapacityMB `
                    -StoragePoolID $configuration.StoragePoolId -AllocType $configuration.Lun.AllocationType `
                    -Description "Integrity validation run $runId"
            })
            if ($lun.Count -gt 0 -and $lun[0].Name -eq $lunName) {
                $lunId = $lun[0].Id
                Register-TestOwnedResource -Kind Lun -Identity $lunName
                Register-CleanupAction -Name 'Remove-DMLun' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMLun' -Kind Lun -Identity $lunName -Action {
                        Remove-DMLun -WebSession $session -LunId $lunId -ImmediateDelete -Confirm:$false
                    }
                }
            }

            if ($owned.Lun.Contains($lunName)) {
                if ([string]$session.version -match '^V6') {
                    Invoke-MutationStep -Name 'Set-DMLun' -Action {
                        Assert-TestOwnedResource -Kind Lun -Identity $lunName
                        Set-DMLun -WebSession $session -LunId $lunId `
                            -Description "Integrity validation updated $runId" -Confirm:$false
                    } | Out-Null
                    Add-MutationReadVerification -Name 'Set-DMLun:ReadBack' -Action {
                        $updated = @(Get-DMlun -WebSession $session -Id $lunId)
                        if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                            throw "Set-DMLun description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                        }
                        $updated
                    } | Out-Null

                    $expandedLunCapacityMB = if ($configuration.Lun.ExpandedCapacityMB -gt 0) {
                        $configuration.Lun.ExpandedCapacityMB
                    }
                    else {
                        $configuration.Lun.CapacityMB + 1024
                    }
                    Invoke-MutationStep -Name 'Set-DMLun:Expand' -Action {
                        Assert-TestOwnedResource -Kind Lun -Identity $lunName
                        Set-DMLun -WebSession $session -LunId $lunId `
                            -Capacity "${expandedLunCapacityMB}MB" -Confirm:$false
                    } | Out-Null
                    $expectedLunCapacityBlocks = ConvertTo-DMCapacityBlock -Capacity "${expandedLunCapacityMB}MB" -UnitlessUnit Blocks
                    Add-MutationReadVerification -Name 'Set-DMLun:Expand:ReadBack' -Action {
                        $updated = @(Get-DMlun -WebSession $session -Id $lunId)
                        if ($updated.Count -gt 0 -and [long]$updated[0].RealCapacity -ne $expectedLunCapacityBlocks) {
                            throw "Set-DMLun capacity mismatch: expected $expectedLunCapacityBlocks blocks, got $($updated[0].RealCapacity)."
                        }
                        $updated
                    } | Out-Null

                    $renameResult = @(Invoke-MutationStep -Name 'Rename-DMLun' -Action {
                        Assert-TestOwnedResource -Kind Lun -Identity $lunName
                        if (@(Get-DMlun -WebSession $session -Name $renamedLunName).Count -gt 0) {
                            throw "A LUN named '$renamedLunName' already exists; refusing to overwrite it."
                        }
                        Rename-DMLun -WebSession $session -LunId $lunId -NewName $renamedLunName -Confirm:$false
                    })
                    if ($renameResult.Count -gt 0) {
                        Update-TestOwnedResourceIdentity -Kind Lun -OldIdentity $lunName -NewIdentity $renamedLunName
                        $lunName = $renamedLunName
                        Add-MutationReadVerification -Name 'Rename-DMLun:ReadBack' -Action {
                            Get-DMlun -WebSession $session -Id $lunId
                        } | Out-Null
                    }
                }
                else {
                    Add-SkippedResult -Name @('Set-DMLun', 'Rename-DMLun') -Status 'NotExecuted' `
                        -Reason 'LUN modification is supported only on Dorado V6 sessions.'
                }
            }

            if ($owned.Lun.Contains($lunName)) {
                $snapshot = @(Invoke-MutationStep -Name 'New-DMLunSnapshot' -ExpectedType 'OceanstorLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    if (@(Get-DMLunSnapshot -WebSession $session -Name $snapshotName | Where-Object Name -EQ $snapshotName).Count -gt 0) {
                        throw "A LUN snapshot named '$snapshotName' already exists; refusing to claim it as test-owned."
                    }
                    New-DMLunSnapshot -WebSession $session -SnapshotName $snapshotName -SourceLunId $lunId `
                        -Description "Integrity validation run $runId"
                })
                if ($snapshot.Count -gt 0 -and $snapshot[0].Name -eq $snapshotName) {
                    Register-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Register-CleanupAction -Name 'Remove-DMLunSnapShot' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMLunSnapShot' -Kind LunSnapshot -Identity $snapshotName -Action {
                            Remove-DMLunSnapShot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                        }
                    }
                }
            }

            if ($owned.LunSnapshot.Contains($snapshotName)) {
                $copy = @(Invoke-MutationStep -Name 'New-DMLunSnapshotCopy' -ExpectedType 'OceanstorLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    if (@(Get-DMLunSnapshot -WebSession $session -Name $snapshotCopyName | Where-Object Name -EQ $snapshotCopyName).Count -gt 0) {
                        throw "A LUN snapshot named '$snapshotCopyName' already exists; refusing to claim it as test-owned."
                    }
                    New-DMLunSnapshotCopy -WebSession $session -SourceSnapShotName $snapshotName `
                        -SnapshotCopyName $snapshotCopyName -Description "Integrity validation run $runId"
                })
                if ($copy.Count -gt 0 -and $copy[0].Name -eq $snapshotCopyName) {
                    Register-TestOwnedResource -Kind LunSnapshot -Identity $snapshotCopyName
                    Register-CleanupAction -Name 'Remove-DMLunSnapShot:Copy' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMLunSnapShot:Copy' -Kind LunSnapshot -Identity $snapshotCopyName -Action {
                            Remove-DMLunSnapShot -WebSession $session -SnapShotName $snapshotCopyName -Confirm:$false
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
                'New-DMLun', 'Set-DMLun', 'Rename-DMLun', 'New-DMLunSnapshot', 'New-DMLunSnapshotCopy', 'Enable-DMLunSnapshot',
                'Restart-DMLunSnapshot', 'Resize-DMLunSnapshot', 'Restore-DMLunSnapshot',
                'Remove-DMLunSnapShot', 'Remove-DMLun'
            ) -Status 'NotConfigured' -Reason 'Set Lun.Enabled = $true and provide StoragePoolId to run the test-owned LUN workflow.'
        }

}
