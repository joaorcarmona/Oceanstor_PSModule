$script:StoragePoolMutationWorkflow = {
    # Unlike every other mutation workflow, this one operates on a PRE-EXISTING storage pool: the
    # module cannot create or delete pools, so a test-owned object is impossible. Safety therefore
    # comes from full reversibility -- the pool's original name is captured, the pool is renamed to a
    # run-unique temporary name, read back, then renamed to its original name and verified. A restore
    # cleanup action (idempotent) renames the pool back if the run aborts mid-round-trip. Nothing else
    # about the pool (capacity, tiers, thresholds, container config, LUN/file-system placement) is
    # ever touched.
    if ($configuration.StoragePool -and $configuration.StoragePool.Enabled) {
        $poolName = $configuration.StoragePool.PoolName

        # Resolve the configured pool by exact name; never auto-pick a pool.
        $pools = @(Get-DMstoragePool -WebSession $session)
        $target = @($pools | Where-Object Name -CEQ $poolName)

        if ($target.Count -ne 1) {
            $reason = if ($target.Count -gt 1) {
                "Storage pool name '$poolName' is ambiguous on this array; rename round-trip skipped to avoid touching the wrong pool."
            }
            else {
                "Configured StoragePool.PoolName '$poolName' was not found; rename round-trip skipped (no pool was modified)."
            }
            Add-SkippedResult -Name @('Rename-DMstoragePool') -Status 'NotConfigured' -Reason $reason
            return
        }

        $originalName = $target[0].Name
        $tempName = New-TestName -Suffix 'pool'

        # Pre-flight reversibility guards, done before any mutation:
        #  - the original name must satisfy the command's own NewName rule so the rename-back leg can
        #    never be rejected by validation (OceanStor already constrains pool names to this set, so
        #    this is defence-in-depth);
        #  - the temporary name must not already belong to another pool.
        if ($originalName -notmatch '^[A-Za-z0-9_.-]+$' -or $originalName.Length -gt 255) {
            Add-SkippedResult -Name @('Rename-DMstoragePool') -Status 'NotConfigured' `
                -Reason "Storage pool '$originalName' has a name outside the reversible rename character set; round-trip skipped to guarantee it can be restored."
            return
        }
        if (@($pools | Where-Object Name -CEQ $tempName).Count -gt 0) {
            Add-SkippedResult -Name @('Rename-DMstoragePool') -Status 'NotConfigured' `
                -Reason "Temporary rename name '$tempName' already exists as a pool; round-trip skipped to avoid claiming another pool's name."
            return
        }

        # Leg 1: rename the pre-existing pool to the temporary name.
        $renamed = @(Invoke-MutationStep -Name 'Rename-DMstoragePool' -Action {
            Rename-DMstoragePool -WebSession $session -StoragePoolName $originalName -NewName $tempName -Confirm:$false
        })

        if ($renamed.Count -gt 0) {
            # Register the restore safety net immediately after the pool is renamed: even if a later
            # step throws or the whole run aborts, Invoke-RegisteredCleanup renames the pool back to
            # its original name. Idempotent -- it re-reads the current name and acts only while the
            # pool still carries the temporary name, so it is a no-op once Leg 2 has restored it.
            Register-CleanupAction -Name 'Rename-DMstoragePool:Restore' -Action {
                $current = @(Get-DMstoragePool -WebSession $session | Where-Object Name -CEQ $tempName)
                if ($current.Count -gt 0) {
                    Invoke-MutationStep -Name 'Rename-DMstoragePool:Restore' -Action {
                        Rename-DMstoragePool -WebSession $session -StoragePoolName $tempName -NewName $originalName -Confirm:$false
                    } | Out-Null
                }
            }

            Add-MutationReadVerification -Name 'Rename-DMstoragePool:ReadBack' -ExpectedType 'OceanStorStoragePool' -Action {
                @(Get-DMstoragePool -WebSession $session | Where-Object Name -CEQ $tempName)
            } | Out-Null

            # Leg 2: rename the pool back to its original name (the main-flow restore). Once this
            # succeeds the registered cleanup action above finds nothing to do.
            Invoke-MutationStep -Name 'Rename-DMstoragePool:Restore' -Action {
                Rename-DMstoragePool -WebSession $session -StoragePoolName $tempName -NewName $originalName -Confirm:$false
            } | Out-Null

            Add-MutationReadVerification -Name 'Rename-DMstoragePool:Restore' -ExpectedType 'OceanStorStoragePool' -Action {
                @(Get-DMstoragePool -WebSession $session | Where-Object Name -CEQ $originalName)
            } | Out-Null
        }
    }
    else {
        Add-SkippedResult -Name @('Rename-DMstoragePool') -Status 'NotConfigured' `
            -Reason 'Enable StoragePool in IntegrityValidationConfig.psd1 and set PoolName to run the reversible storage-pool rename round-trip.'
    }
}
