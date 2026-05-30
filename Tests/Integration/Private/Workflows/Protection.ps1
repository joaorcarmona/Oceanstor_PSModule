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
                'New-DMProtectionGroup', 'Remove-DMProtectionGroup', 'New-DMSnapshotConsistencyGroup',
                'New-DMSnapshotConsistencyGroupCopy', 'Enable-DMSnapshotConsistencyGroup',
                'Restart-DMSnapshotConsistencyGroup', 'Restore-DMSnapshotConsistencyGroup',
                'Remove-DMSnapshotConsistencyGroup'
            ) -Status 'NotConfigured' -Reason 'Set Protection.Enabled = $true with Lun and LunGroup enabled to run the test-owned protection workflow.'
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMProtectionGroup', 'Remove-DMProtectionGroup', 'New-DMSnapshotConsistencyGroup',
                'New-DMSnapshotConsistencyGroupCopy', 'Enable-DMSnapshotConsistencyGroup',
                'Restart-DMSnapshotConsistencyGroup', 'Restore-DMSnapshotConsistencyGroup',
                'Remove-DMSnapshotConsistencyGroup'
            ) -Status 'Blocked' -Reason 'Protection validation could not run because the test-owned LUN and LUN-group association was not created successfully.'
        }

}
