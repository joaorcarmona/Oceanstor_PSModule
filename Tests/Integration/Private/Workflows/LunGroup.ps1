$script:LunGroupMutationWorkflow = {
        if ($configuration.LunGroup.Enabled) {
            $lunGroup = @(Invoke-MutationStep -Name 'New-DMLunGroup' -ExpectedType 'OceanStorLunGroup' -Action {
                if (@(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $lunGroupName).Count -gt 0) {
                    throw "A LUN group named '$lunGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMLunGroup -WebSession $session -Name $lunGroupName `
                    -ApplicationType $configuration.LunGroup.ApplicationType -Description "Integrity validation run $runId"
            })
            if ($lunGroup.Count -gt 0 -and $lunGroup[0].Name -eq $lunGroupName) {
                Register-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                Register-CleanupAction -Name 'Remove-DMLunGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMLunGroup' -Kind LunGroup -Identity $lunGroupName -Action {
                        Remove-DMLunGroup -WebSession $session -LunGroupName $lunGroupName -Confirm:$false
                    }
                }
            }
            if ($owned.LunGroup.Contains($lunGroupName)) {
                Invoke-MutationStep -Name 'Set-DMLunGroup' -Action {
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Set-DMLunGroup -WebSession $session -LunGroupName $lunGroupName `
                        -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMLunGroup:ReadBack' -ExpectedType 'OceanStorLunGroup' -Action {
                    $updated = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $lunGroupName)
                    if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMLunGroup description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                    }
                    $updated
                } | Out-Null
                $renameResult = @(Invoke-MutationStep -Name 'Rename-DMLunGroup' -Action {
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    if (@(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $renamedLunGroupName).Count -gt 0) {
                        throw "A LUN group named '$renamedLunGroupName' already exists; refusing to overwrite it."
                    }
                    Rename-DMLunGroup -WebSession $session -LunGroupName $lunGroupName `
                        -NewName $renamedLunGroupName -Confirm:$false
                })
                if ($renameResult.Count -gt 0) {
                    Update-TestOwnedResourceIdentity -Kind LunGroup -OldIdentity $lunGroupName -NewIdentity $renamedLunGroupName
                    $lunGroupName = $renamedLunGroupName
                    Add-MutationReadVerification -Name 'Rename-DMLunGroup:ReadBack' -ExpectedType 'OceanStorLunGroup' -Action {
                        Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $lunGroupName
                    } | Out-Null
                }
            }
            if ($owned.Lun.Contains($lunName) -and $owned.LunGroup.Contains($lunGroupName)) {
                $associateLun = @(Invoke-MutationStep -Name 'Add-DMLunToLunGroup' -Action {
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Add-DMLunToLunGroup -WebSession $session -LunName $lunName -LunGroupName $lunGroupName -Confirm:$false
                })
                if ($associateLun.Count -gt 0) {
                    $lunGroupContainsLun = $true
                    Register-CleanupAction -Name 'Remove-DMLunFromLunGroup' -Action {
                        Invoke-MutationStep -Name 'Remove-DMLunFromLunGroup' -Action {
                            Assert-TestOwnedResource -Kind Lun -Identity $lunName
                            Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                            Remove-DMLunFromLunGroup -WebSession $session -LunName $lunName -LunGroupName $lunGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }

            if ($owned.LunGroup.Contains($lunGroupName) -and $configuration.LunGroup.EnablePipelineBatchCoverage) {
                # Multi-object pipeline coverage: proves Get-DMlun | Set-DMLun / Add-DMLunToLunGroup /
                # Remove-DMLun each process every piped LUN (not just the last one), and that a
                # deliberately invalid item among real ones is reported as a non-terminating error
                # without aborting the rest -- the exact regression this workflow exists to catch.
                $pipeLunNames = @(1..3 | ForEach-Object { New-TestName -Suffix "lun_pipe$_" })
                $pipeLunsCreated = [System.Collections.Generic.List[string]]::new()
                Invoke-MutationStep -Name 'New-DMLun:PipelineBatch' -Action {
                    foreach ($pipeLunName in $pipeLunNames) {
                        if (@(Get-DMlun -WebSession $session -Name $pipeLunName | Where-Object Name -EQ $pipeLunName).Count -gt 0) {
                            throw "A LUN named '$pipeLunName' already exists; refusing to claim it as test-owned."
                        }
                        $created = @(New-DMLun -WebSession $session -LunName $pipeLunName -Capacity $configuration.Lun.CapacityMB `
                                -StoragePoolID $configuration.StoragePoolId -AllocType $configuration.Lun.AllocationType `
                                -Description "Integrity validation pipeline $runId")
                        if ($created.Count -eq 0 -or $created[0].Name -ne $pipeLunName) {
                            throw "New-DMLun did not return the expected pipeline LUN '$pipeLunName'."
                        }
                        Register-TestOwnedResource -Kind Lun -Identity $pipeLunName
                        $capturedPipeLunName = $pipeLunName
                        $capturedPipeLunId = $created[0].Id
                        Register-CleanupAction -Name "Remove-DMLun:$capturedPipeLunName" -Action ({
                            Invoke-OwnedRemoval -Name "Remove-DMLun:$capturedPipeLunName" -Kind Lun -Identity $capturedPipeLunName -Action {
                                if ($capturedPipeLunId) {
                                    Remove-DMLun -WebSession $session -LunId $capturedPipeLunId -ImmediateDelete -Confirm:$false
                                }
                                else {
                                    Remove-DMLun -WebSession $session -LunName $capturedPipeLunName -ImmediateDelete -Confirm:$false
                                }
                            }
                        }.GetNewClosure())
                        [void]$pipeLunsCreated.Add($pipeLunName)
                    }
                    [pscustomobject]@{ Created = $pipeLunsCreated.Count }
                } | Out-Null

                if ($pipeLunsCreated.Count -eq 3) {
                    Invoke-MutationStep -Name 'Set-DMLun:PipelineBatch' -Action {
                        foreach ($n in $pipeLunsCreated) { Assert-TestOwnedResource -Kind Lun -Identity $n }
                        $pipeLunsCreated | ForEach-Object { [pscustomobject]@{ Name = $_ } } |
                            Set-DMLun -WebSession $session -Description "Integrity validation pipeline batch $runId" -Confirm:$false
                    } | Out-Null
                    Add-MutationReadVerification -Name 'Set-DMLun:PipelineBatch:ReadBack' -Action {
                        $updated = @(
                            foreach ($n in $pipeLunsCreated) {
                                Get-DMlun -WebSession $session -Name $n | Where-Object {
                                    $_.Name -eq $n -and $_.Description -eq "Integrity validation pipeline batch $runId"
                                }
                            }
                        )
                        if ($updated.Count -ne $pipeLunsCreated.Count) {
                            throw "Set-DMLun pipeline batch mismatch: expected $($pipeLunsCreated.Count) LUNs updated, found $($updated.Count) -- exactly the 'only the last piped item is processed' regression this checks for."
                        }
                        $updated
                    } | Out-Null

                    Invoke-MutationStep -Name 'Add-DMLunToLunGroup:PipelineBatch' -Action {
                        foreach ($n in $pipeLunsCreated) { Assert-TestOwnedResource -Kind Lun -Identity $n }
                        Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                        $pipeLunsCreated | ForEach-Object { [pscustomobject]@{ Name = $_ } } |
                            Add-DMLunToLunGroup -WebSession $session -LunGroupName $lunGroupName -Confirm:$false
                    } | Out-Null
                    Add-MutationReadVerification -Name 'Add-DMLunToLunGroup:PipelineBatch:ReadBack' -Action {
                        $group = @(Get-DMlunGroup -WebSession $session -Name $lunGroupName | Where-Object Name -EQ $lunGroupName)[0]
                        $members = @(Get-DMlun -WebSession $session -LunGroup $group)
                        $missing = @($pipeLunsCreated | Where-Object { $members.Name -notcontains $_ })
                        if ($missing.Count -gt 0) {
                            throw "Add-DMLunToLunGroup pipeline batch did not associate: $($missing -join ', ')."
                        }
                        $members
                    } | Out-Null
                    # Only the LUN that survives to the end of this workflow still needs its
                    # membership torn down via registered cleanup; the array requires
                    # disassociation before a LUN can be deleted (confirmed live: deleting a LUN
                    # still in a group fails with "The specified LUN already exists in the LUN
                    # group"), so the other two are disassociated explicitly below before they're
                    # removed in the same step.
                    $cleanupMemberLunName = $pipeLunsCreated[2]
                    Register-CleanupAction -Name "Remove-DMLunFromLunGroup:$cleanupMemberLunName" -Action ({
                        Invoke-MutationStep -Name "Remove-DMLunFromLunGroup:$cleanupMemberLunName" -Action {
                            Assert-TestOwnedResource -Kind Lun -Identity $cleanupMemberLunName
                            Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                            Remove-DMLunFromLunGroup -WebSession $session -LunName $cleanupMemberLunName -LunGroupName $lunGroupName -Confirm:$false
                        } | Out-Null
                    }.GetNewClosure())

                    Invoke-MutationStep -Name 'Remove-DMLunFromLunGroup:PipelineBatch' -Action {
                        foreach ($n in $pipeLunsCreated[0, 1]) {
                            Assert-TestOwnedResource -Kind Lun -Identity $n
                            Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                            Remove-DMLunFromLunGroup -WebSession $session -LunName $n -LunGroupName $lunGroupName -Confirm:$false
                        }
                    } | Out-Null
                    Add-MutationReadVerification -Name 'Remove-DMLunFromLunGroup:PipelineBatch:ReadBack' -Action {
                        $group = @(Get-DMlunGroup -WebSession $session -Name $lunGroupName | Where-Object Name -EQ $lunGroupName)[0]
                        $members = @(Get-DMlun -WebSession $session -LunGroup $group)
                        $stillAssociated = @($pipeLunsCreated[0, 1] | Where-Object { $members.Name -contains $_ })
                        if ($stillAssociated.Count -gt 0) {
                            throw "Remove-DMLunFromLunGroup pipeline batch did not remove membership for: $($stillAssociated -join ', ')."
                        }
                        if ($members.Name -notcontains $pipeLunsCreated[2]) {
                            throw "Expected '$($pipeLunsCreated[2])' to remain associated for cleanup verification, but it is no longer a LUN group member."
                        }
                        @($members | Where-Object { $pipeLunsCreated -contains $_.Name })
                    } | Out-Null

                    # Note: Remove-DMLun's "Invalid LunName" message lists the *valid* names, it
                    # does not echo back the requested (invalid) name, so this only asserts that a
                    # non-terminating error occurred and that the two real LUNs still got removed
                    # despite it -- not the exact wording.
                    $bogusLunName = New-TestName -Suffix 'lun_pipe_missing'
                    $continueOnErrorResult = @(Invoke-MutationStep -Name 'Remove-DMLun:PipelineBatchContinueOnError' -Action {
                        foreach ($n in $pipeLunsCreated[0, 1]) { Assert-TestOwnedResource -Kind Lun -Identity $n }
                        $removeErrors = $null
                        @($pipeLunsCreated[0], $bogusLunName, $pipeLunsCreated[1]) | ForEach-Object { [pscustomobject]@{ Name = $_ } } |
                            Remove-DMLun -WebSession $session -ImmediateDelete -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors |
                            Out-Null
                        if ($removeErrors.Count -eq 0) {
                            throw "Expected a non-terminating error for the deliberately invalid LUN name '$bogusLunName', but none was reported -- the pipeline may have stopped instead of continuing."
                        }
                        $stillPresent = @(
                            foreach ($n in $pipeLunsCreated[0, 1]) {
                                Get-DMlun -WebSession $session -Name $n | Where-Object Name -EQ $n
                            }
                        )
                        if ($stillPresent.Count -gt 0) {
                            throw "Expected both real pipelined LUNs to be removed despite the invalid third item; still present: $($stillPresent.Name -join ', ')."
                        }
                        [pscustomobject]@{ Code = 0 }
                    })
                    if ($continueOnErrorResult.Count -gt 0) {
                        # Only mark these complete once the read-back inside the step above
                        # actually confirmed removal -- if the step failed, leave both test-owned
                        # so their normal per-LUN cleanup (registered at creation time) still runs
                        # instead of silently orphaning them.
                        Complete-TestOwnedResource -Kind Lun -Identity $pipeLunsCreated[0]
                        Complete-TestOwnedResource -Kind Lun -Identity $pipeLunsCreated[1]
                    }
                    # pipeLunsCreated[2] remains test-owned; its registered cleanup actions above
                    # (membership removal, then LUN removal) handle it at the end of the run.
                }
                else {
                    Add-SkippedResult -Name @(
                        'Set-DMLun:PipelineBatch',
                        'Add-DMLunToLunGroup:PipelineBatch',
                        'Remove-DMLunFromLunGroup:PipelineBatch',
                        'Remove-DMLun:PipelineBatchContinueOnError'
                    ) -Status 'Blocked' -Reason "New-DMLun:PipelineBatch created $($pipeLunsCreated.Count) of 3 required LUNs."
                }
            }
            elseif ($owned.LunGroup.Contains($lunGroupName)) {
                Add-SkippedResult -Name @(
                    'New-DMLun:PipelineBatch',
                    'Set-DMLun:PipelineBatch',
                    'Add-DMLunToLunGroup:PipelineBatch',
                    'Remove-DMLunFromLunGroup:PipelineBatch',
                    'Remove-DMLun:PipelineBatchContinueOnError'
                ) -Status 'NotConfigured' -Reason 'Set LunGroup.EnablePipelineBatchCoverage = $true or call the runner with -RunPipelineBatchCoverage to run expensive multi-LUN pipeline regression coverage.'
            }
        }
        else {
            Add-SkippedResult -Name @('New-DMLunGroup', 'Set-DMLunGroup', 'Rename-DMLunGroup', 'Add-DMLunToLunGroup', 'Remove-DMLunFromLunGroup', 'Remove-DMLunGroup') `
                -Status 'NotConfigured' -Reason 'Set LunGroup.Enabled = $true with Lun.Enabled = $true to run the test-owned LUN group workflow.'
        }

}
