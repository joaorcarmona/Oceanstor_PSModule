$script:LunGroupMutationWorkflow = {
        if ($configuration.LunGroup.Enabled) {
            $lunGroup = @(Invoke-MutationStep -Name 'New-DMLunGroup' -ExpectedType 'OceanStorLunGroup' -Action {
                if (@(Get-DMlunGroups -WebSession $session | Where-Object Name -EQ $lunGroupName).Count -gt 0) {
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
        }
        else {
            Add-SkippedResult -Name @('New-DMLunGroup', 'Add-DMLunToLunGroup', 'Remove-DMLunFromLunGroup', 'Remove-DMLunGroup') `
                -Status 'NotConfigured' -Reason 'Set LunGroup.Enabled = $true with Lun.Enabled = $true to run the test-owned LUN group workflow.'
        }

}
