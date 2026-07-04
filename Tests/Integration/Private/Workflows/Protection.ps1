$script:ProtectionMutationWorkflow = {
        if ($configuration.Protection.Enabled -and $lunGroupContainsLun) {
            $protectionGroup = @(Invoke-MutationStep -Name 'New-DMProtectionGroup' -ExpectedType 'OceanstorProtectionGroup' -Action {
                Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                if (@(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $protectionGroupName).Count -gt 0) {
                    throw "A protection group named '$protectionGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMProtectionGroup -WebSession $session -Name $protectionGroupName -LunGroupName $lunGroupName `
                    -Description "Integrity validation run $runId"
            })
            if ($protectionGroup.Count -gt 0 -and $protectionGroup[0].Name -eq $protectionGroupName) {
                Register-TestOwnedResource -Kind ProtectionGroup -Identity $protectionGroupName
                Register-CleanupAction -Name 'Remove-DMProtectionGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMProtectionGroup' -Kind ProtectionGroup -Identity $protectionGroupName -Action {
                        Remove-DMProtectionGroup -WebSession $session -Name $protectionGroupName -Confirm:$false
                    }
                }
            }

            if ($owned.ProtectionGroup.Contains($protectionGroupName)) {
                Invoke-MutationStep -Name 'Set-DMProtectionGroup' -Action {
                    Assert-TestOwnedResource -Kind ProtectionGroup -Identity $protectionGroupName
                    Set-DMProtectionGroup -WebSession $session -Name $protectionGroupName `
                        -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMProtectionGroup:ReadBack' -ExpectedType 'OceanstorProtectionGroup' -Action {
                    $updated = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $protectionGroupName)
                    if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMProtectionGroup description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                    }
                    $updated
                } | Out-Null
                $renameResult = @(Invoke-MutationStep -Name 'Rename-DMProtectionGroup' -Action {
                    Assert-TestOwnedResource -Kind ProtectionGroup -Identity $protectionGroupName
                    if (@(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $renamedProtectionGroupName).Count -gt 0) {
                        throw "A protection group named '$renamedProtectionGroupName' already exists; refusing to overwrite it."
                    }
                    Rename-DMProtectionGroup -WebSession $session -Name $protectionGroupName `
                        -NewName $renamedProtectionGroupName -Confirm:$false
                })
                if ($renameResult.Count -gt 0) {
                    Update-TestOwnedResourceIdentity -Kind ProtectionGroup -OldIdentity $protectionGroupName -NewIdentity $renamedProtectionGroupName
                    $protectionGroupName = $renamedProtectionGroupName
                    Add-MutationReadVerification -Name 'Rename-DMProtectionGroup:ReadBack' -ExpectedType 'OceanstorProtectionGroup' -Action {
                        Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $protectionGroupName
                    } | Out-Null
                }
                # Add/Remove-DMLunToProtectionGroup are exercised below against a second, LUN-type
                # protection group created with no backing LUN group. A dedicated standalone LUN is
                # created here for that association: the device rejects adding an individual LUN to a
                # LUN-group-backed protection group (error 1073807382), so the first protection group
                # (bound to $lunGroupName) cannot be reused for it.
                $protectionAssociationLun = @(Invoke-MutationStep -Name 'New-DMLun:ProtectionAssociation' -Action {
                    if (@(Get-DMlun -WebSession $session | Where-Object Name -EQ $protectionLunName).Count -gt 0) {
                        throw "A LUN named '$protectionLunName' already exists; refusing to claim it as test-owned."
                    }
                    New-DMLun -WebSession $session -LunName $protectionLunName -Capacity $configuration.Lun.CapacityMB `
                        -StoragePoolID $configuration.StoragePoolId -AllocType $configuration.Lun.AllocationType `
                        -Description "Integrity validation run $runId"
                })
                if ($protectionAssociationLun.Count -gt 0 -and $protectionAssociationLun[0].Name -eq $protectionLunName) {
                    Register-TestOwnedResource -Kind Lun -Identity $protectionLunName
                    Register-CleanupAction -Name 'Remove-DMLun:ProtectionAssociation' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMLun:ProtectionAssociation' -Kind Lun -Identity $protectionLunName -Action {
                            Remove-DMLun -WebSession $session -LunName $protectionLunName -ImmediateDelete -Confirm:$false
                        }
                    }

                    $lunProtectionGroup = @(Invoke-MutationStep -Name 'New-DMProtectionGroup:LunType' -ExpectedType 'OceanstorProtectionGroup' -Action {
                        if (@(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $lunProtectionGroupName).Count -gt 0) {
                            throw "A protection group named '$lunProtectionGroupName' already exists; refusing to claim it as test-owned."
                        }
                        New-DMProtectionGroup -WebSession $session -Name $lunProtectionGroupName -Description "Integrity validation run $runId"
                    })
                    if ($lunProtectionGroup.Count -gt 0 -and $lunProtectionGroup[0].Name -eq $lunProtectionGroupName) {
                        Register-TestOwnedResource -Kind ProtectionGroup -Identity $lunProtectionGroupName
                        Register-CleanupAction -Name 'Remove-DMProtectionGroup:LunType' -Action {
                            Invoke-OwnedRemoval -Name 'Remove-DMProtectionGroup:LunType' -Kind ProtectionGroup -Identity $lunProtectionGroupName -Action {
                                Remove-DMProtectionGroup -WebSession $session -Name $lunProtectionGroupName -Confirm:$false
                            }
                        }

                        $associateLunToProtectionGroup = @(Invoke-MutationStep -Name 'Add-DMLunToProtectionGroup' -Action {
                            Assert-TestOwnedResource -Kind Lun -Identity $protectionLunName
                            Assert-TestOwnedResource -Kind ProtectionGroup -Identity $lunProtectionGroupName
                            Add-DMLunToProtectionGroup -WebSession $session -Name $lunProtectionGroupName -LunName $protectionLunName -Confirm:$false
                        })
                        if ($associateLunToProtectionGroup.Count -gt 0) {
                            Register-CleanupAction -Name 'Remove-DMLunFromProtectionGroup' -Action {
                                Invoke-MutationStep -Name 'Remove-DMLunFromProtectionGroup' -Action {
                                    Assert-TestOwnedResource -Kind Lun -Identity $protectionLunName
                                    Assert-TestOwnedResource -Kind ProtectionGroup -Identity $lunProtectionGroupName
                                    Remove-DMLunFromProtectionGroup -WebSession $session -Name $lunProtectionGroupName -LunName $protectionLunName -Confirm:$false
                                } | Out-Null
                            }
                        }
                    }
                }

                $consistencyGroup = @(Invoke-MutationStep -Name 'New-DMSnapshotConsistencyGroup' -ExpectedType 'OceanstorSnapshotConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind ProtectionGroup -Identity $protectionGroupName
                    if (@(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $consistencyGroupName).Count -gt 0) {
                        throw "A snapshot consistency group named '$consistencyGroupName' already exists; refusing to claim it as test-owned."
                    }
                    New-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName `
                        -ProtectionGroupName $protectionGroupName -Description "Integrity validation run $runId"
                })
                if ($consistencyGroup.Count -gt 0 -and $consistencyGroup[0].Name -eq $consistencyGroupName) {
                    Register-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                    Register-CleanupAction -Name 'Remove-DMSnapshotConsistencyGroup' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMSnapshotConsistencyGroup' -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName -Action {
                            Wait-DMSnapshotConsistencyGroupReadyForRemoval -Name $consistencyGroupName
                            Remove-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName -Confirm:$false
                        }
                    }
                }
            }

            if ($owned.SnapshotConsistencyGroup.Contains($consistencyGroupName)) {
                $consistencyCopy = @(Invoke-MutationStep -Name 'New-DMSnapshotConsistencyGroupCopy' -ExpectedType 'OceanstorSnapshotConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                    New-DMSnapshotConsistencyGroupCopy -WebSession $session -SourceName $consistencyGroupName `
                        -Name $consistencyCopyName -Description "Integrity validation run $runId"
                })
                if ($consistencyCopy.Count -gt 0 -and $consistencyCopy[0].Name -eq $consistencyCopyName) {
                    Register-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyCopyName
                    Register-CleanupAction -Name 'Remove-DMSnapshotConsistencyGroup:Copy' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMSnapshotConsistencyGroup:Copy' -Kind SnapshotConsistencyGroup -Identity $consistencyCopyName -Action {
                            Remove-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyCopyName -Confirm:$false
                        }
                    }
                }
                $consistencyState = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $consistencyGroupName)[0]
                if ($consistencyState.'Running Status' -eq 'Unactivated') {
                    Invoke-MutationStep -Name 'Enable-DMSnapshotConsistencyGroup' -Action {
                        Assert-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                        Enable-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName -Confirm:$false
                    } | Out-Null
                }
                else {
                    Add-SkippedResult -Name 'Enable-DMSnapshotConsistencyGroup' -Status 'NotExecuted' `
                        -Reason "The newly created snapshot consistency group is '$($consistencyState.'Running Status')'; activation is only valid while it is Unactivated."
                }
                Invoke-MutationStep -Name 'Restart-DMSnapshotConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                    Restart-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Restore-DMSnapshotConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Restore-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName -Confirm:$false
                } | Out-Null
            }

        }
        elseif (-not $configuration.Protection.Enabled) {
            Add-SkippedResult -Name @(
                'New-DMProtectionGroup', 'Remove-DMProtectionGroup', 'Set-DMProtectionGroup', 'Rename-DMProtectionGroup',
                'Add-DMLunToProtectionGroup', 'Remove-DMLunFromProtectionGroup', 'New-DMSnapshotConsistencyGroup',
                'New-DMSnapshotConsistencyGroupCopy', 'Enable-DMSnapshotConsistencyGroup',
                'Restart-DMSnapshotConsistencyGroup', 'Restore-DMSnapshotConsistencyGroup',
                'Remove-DMSnapshotConsistencyGroup'
            ) -Status 'NotConfigured' -Reason 'Set Protection.Enabled = $true with Lun and LunGroup enabled to run the test-owned protection workflow.'
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMProtectionGroup', 'Remove-DMProtectionGroup', 'Set-DMProtectionGroup', 'Rename-DMProtectionGroup',
                'Add-DMLunToProtectionGroup', 'Remove-DMLunFromProtectionGroup', 'New-DMSnapshotConsistencyGroup',
                'New-DMSnapshotConsistencyGroupCopy', 'Enable-DMSnapshotConsistencyGroup',
                'Restart-DMSnapshotConsistencyGroup', 'Restore-DMSnapshotConsistencyGroup',
                'Remove-DMSnapshotConsistencyGroup'
            ) -Status 'Blocked' -Reason 'Protection validation could not run because the test-owned LUN and LUN-group association was not created successfully.'
        }

}
