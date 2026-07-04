$script:DirectMappingMutationWorkflow = {
        if ($configuration.Mapping.Enabled) {
            $mapLun = @(Invoke-MutationStep -Name 'New-DMLun:DirectMapping' -Action {
                if (@(Get-DMlun -WebSession $session -Name $mapLunName | Where-Object Name -EQ $mapLunName).Count -gt 0) {
                    throw "A LUN named '$mapLunName' already exists; refusing to claim it as test-owned."
                }
                New-DMLun -WebSession $session -LunName $mapLunName -Capacity $configuration.Lun.CapacityMB `
                    -StoragePoolID $configuration.StoragePoolId -AllocType $configuration.Lun.AllocationType `
                    -Description "Integrity validation run $runId"
            })
            if ($mapLun.Count -gt 0 -and $mapLun[0].Name -eq $mapLunName) {
                $mapLunId = $mapLun[0].Id
                Register-TestOwnedResource -Kind Lun -Identity $mapLunName
                Register-CleanupAction -Name 'Remove-DMLun:DirectMapping' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMLun:DirectMapping' -Kind Lun -Identity $mapLunName -Action {
                        Remove-DMLun -WebSession $session -LunId $mapLunId -ImmediateDelete -Confirm:$false
                    }
                }
            }

            $mapHost = @(Invoke-MutationStep -Name 'New-DMHost:DirectMapping' -ExpectedType 'OceanStorHost' -Action {
                if (@(Get-DMhost -WebSession $session -Name $mapHostName).Count -gt 0) {
                    throw "A host named '$mapHostName' already exists; refusing to claim it as test-owned."
                }
                New-DMHost -WebSession $session -Name $mapHostName -OperatingSystem $configuration.Host.OperatingSystem `
                    -Description "Integrity validation run $runId"
            })
            if ($mapHost.Count -gt 0 -and $mapHost[0].Name -eq $mapHostName) {
                Register-TestOwnedResource -Kind Host -Identity $mapHostName
                Register-CleanupAction -Name 'Remove-DMHost:DirectMapping' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMHost:DirectMapping' -Kind Host -Identity $mapHostName -Action {
                        Remove-DMHost -WebSession $session -HostName $mapHostName -Confirm:$false
                    }
                }
            }

            $mapHostGroup = @(Invoke-MutationStep -Name 'New-DMHostGroup:DirectMapping' -ExpectedType 'OceanStorHostGroup' -Action {
                if (@(Get-DMhostGroup -WebSession $session -Name $mapHostGroupName).Count -gt 0) {
                    throw "A host group named '$mapHostGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMHostGroup -WebSession $session -Name $mapHostGroupName -Description "Integrity validation run $runId"
            })
            if ($mapHostGroup.Count -gt 0 -and $mapHostGroup[0].Name -eq $mapHostGroupName) {
                Register-TestOwnedResource -Kind HostGroup -Identity $mapHostGroupName
                Register-CleanupAction -Name 'Remove-DMHostGroup:DirectMapping' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMHostGroup:DirectMapping' -Kind HostGroup -Identity $mapHostGroupName -Action {
                        Remove-DMHostGroup -WebSession $session -HostGroupName $mapHostGroupName -Confirm:$false
                    }
                }
            }

            if ($owned.Lun.Contains($mapLunName) -and $owned.Host.Contains($mapHostName)) {
                $lunHostMapping = @(Invoke-MutationStep -Name 'Add-DMmapLunToHost' -ExpectedType 'OceanStorMappingView' -Action {
                    Assert-TestOwnedResource -Kind Lun -Identity $mapLunName
                    Assert-TestOwnedResource -Kind Host -Identity $mapHostName
                    Add-DMmapLunToHost -WebSession $session -LunName $mapLunName -HostName $mapHostName -Confirm:$false
                })
                if ($lunHostMapping.Count -gt 0) {
                    Register-CleanupAction -Name 'Remove-DMmapLunFromHost' -Action {
                        Invoke-MutationStep -Name 'Remove-DMmapLunFromHost' -Action {
                            Assert-TestOwnedResource -Kind Lun -Identity $mapLunName
                            Assert-TestOwnedResource -Kind Host -Identity $mapHostName
                            Remove-DMmapLunFromHost -WebSession $session -LunName $mapLunName -HostName $mapHostName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
            else {
                Add-SkippedResult -Name @('Add-DMmapLunToHost', 'Remove-DMmapLunFromHost') `
                    -Status 'Blocked' -Reason 'Direct LUN-to-host mapping could not run because a dedicated, standalone test-owned LUN or dedicated mapping host was not created successfully.'
            }

            if ($owned.LunGroup.Contains($lunGroupName) -and $owned.Host.Contains($mapHostName)) {
                $lunGroupHostMapping = @(Invoke-MutationStep -Name 'Add-DMmapLunGroupToHost' -ExpectedType 'OceanStorMappingView' -Action {
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Assert-TestOwnedResource -Kind Host -Identity $mapHostName
                    Add-DMmapLunGroupToHost -WebSession $session -LunGroupName $lunGroupName -HostName $mapHostName -Confirm:$false
                })
                if ($lunGroupHostMapping.Count -gt 0) {
                    Register-CleanupAction -Name 'Remove-DMunmapLunGroupFromHost' -Action {
                        Invoke-MutationStep -Name 'Remove-DMunmapLunGroupFromHost' -Action {
                            Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                            Assert-TestOwnedResource -Kind Host -Identity $mapHostName
                            Remove-DMunmapLunGroupFromHost -WebSession $session -LunGroupName $lunGroupName -HostName $mapHostName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
            else {
                Add-SkippedResult -Name @('Add-DMmapLunGroupToHost', 'Remove-DMunmapLunGroupFromHost') `
                    -Status 'Blocked' -Reason 'Direct LUN-group-to-host mapping could not run because a test-owned LUN group or dedicated mapping host was not created successfully.'
            }

            if ($owned.LunGroup.Contains($lunGroupName) -and $owned.HostGroup.Contains($mapHostGroupName)) {
                $lunGroupHostGroupMapping = @(Invoke-MutationStep -Name 'Add-DMmapLunGroupToHostGroup' -ExpectedType 'OceanStorMappingView' -Action {
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Assert-TestOwnedResource -Kind HostGroup -Identity $mapHostGroupName
                    Add-DMmapLunGroupToHostGroup -WebSession $session -LunGroupName $lunGroupName -HostGroupName $mapHostGroupName -Confirm:$false
                })
                if ($lunGroupHostGroupMapping.Count -gt 0) {
                    Register-CleanupAction -Name 'Remove-DMunmapLunGroupFromHostGroup' -Action {
                        Invoke-MutationStep -Name 'Remove-DMunmapLunGroupFromHostGroup' -Action {
                            Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                            Assert-TestOwnedResource -Kind HostGroup -Identity $mapHostGroupName
                            Remove-DMunmapLunGroupFromHostGroup -WebSession $session -LunGroupName $lunGroupName -HostGroupName $mapHostGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
            else {
                Add-SkippedResult -Name @('Add-DMmapLunGroupToHostGroup', 'Remove-DMunmapLunGroupFromHostGroup') `
                    -Status 'Blocked' -Reason 'Direct LUN-group-to-host-group mapping could not run because a test-owned LUN group or dedicated mapping host group was not created successfully.'
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMLun:DirectMapping', 'Remove-DMLun:DirectMapping',
                'New-DMHost:DirectMapping', 'New-DMHostGroup:DirectMapping', 'Remove-DMHost:DirectMapping', 'Remove-DMHostGroup:DirectMapping',
                'Add-DMmapLunToHost', 'Remove-DMmapLunFromHost',
                'Add-DMmapLunGroupToHost', 'Remove-DMunmapLunGroupFromHost',
                'Add-DMmapLunGroupToHostGroup', 'Remove-DMunmapLunGroupFromHostGroup'
            ) -Status 'NotConfigured' -Reason 'Set Mapping.Enabled = $true to run the direct LUN/host mapping workflow.'
        }

}
