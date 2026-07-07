$script:MappingMutationWorkflow = {
        if ($configuration.Mapping.Enabled) {
            $portGroup = @(Invoke-MutationStep -Name 'New-DMPortGroup' -ExpectedType 'OceanstorPortGroup' -Action {
                if (@(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $portGroupName).Count -gt 0) {
                    throw "A port group named '$portGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMPortGroup -WebSession $session -Name $portGroupName -Description "Integrity validation run $runId"
            })
            if ($portGroup.Count -gt 0 -and $portGroup[0].Name -eq $portGroupName) {
                Register-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                Register-CleanupAction -Name 'Remove-DMPortGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMPortGroup' -Kind PortGroup -Identity $portGroupName -Action {
                        Remove-DMPortGroup -WebSession $session -PortGroupName $portGroupName -Confirm:$false
                    }
                }
            }
            if ($owned.PortGroup.Contains($portGroupName)) {
                Invoke-MutationStep -Name 'Set-DMPortGroup' -Action {
                    Assert-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                    Set-DMPortGroup -WebSession $session -PortGroupName $portGroupName `
                        -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMPortGroup:ReadBack' -ExpectedType 'OceanstorPortGroup' -Action {
                    $updated = @(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $portGroupName)
                    if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMPortGroup description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                    }
                    $updated
                } | Out-Null
                $renameResult = @(Invoke-MutationStep -Name 'Rename-DMPortGroup' -Action {
                    Assert-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                    if (@(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $renamedPortGroupName).Count -gt 0) {
                        throw "A port group named '$renamedPortGroupName' already exists; refusing to overwrite it."
                    }
                    Rename-DMPortGroup -WebSession $session -PortGroupName $portGroupName `
                        -NewName $renamedPortGroupName -Confirm:$false
                })
                if ($renameResult.Count -gt 0) {
                    Update-TestOwnedResourceIdentity -Kind PortGroup -OldIdentity $portGroupName -NewIdentity $renamedPortGroupName
                    $portGroupName = $renamedPortGroupName
                    Add-MutationReadVerification -Name 'Rename-DMPortGroup:ReadBack' -ExpectedType 'OceanstorPortGroup' -Action {
                        Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $portGroupName
                    } | Out-Null
                }
            }
            $mappingView = @(Invoke-MutationStep -Name 'New-DMMappingView' -ExpectedType 'OceanStorMappingView' -Action {
                if (@(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $mappingViewName).Count -gt 0) {
                    throw "A mapping view named '$mappingViewName' already exists; refusing to claim it as test-owned."
                }
                New-DMMappingView -WebSession $session -Name $mappingViewName -Description "Integrity validation run $runId"
            })
            if ($mappingView.Count -gt 0 -and $mappingView[0].Name -eq $mappingViewName) {
                Register-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                Register-CleanupAction -Name 'Remove-DMMappingView' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMMappingView' -Kind MappingView -Identity $mappingViewName -Action {
                        Remove-DMMappingView -WebSession $session -MappingViewName $mappingViewName -Confirm:$false
                    }
                }
            }
            if ($owned.MappingView.Contains($mappingViewName)) {
                Invoke-MutationStep -Name 'Set-DMMappingView' -Action {
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Set-DMMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMMappingView:ReadBack' -ExpectedType 'OceanStorMappingView' -Action {
                    $updated = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $mappingViewName)
                    if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMMappingView description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                    }
                    $updated
                } | Out-Null
            }
            if ($owned.HostGroup.Contains($hostGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                $mapHostGroup = @(Invoke-MutationStep -Name 'Add-DMHostGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMHostGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -HostGroupName $hostGroupName -Confirm:$false
                })
                if ($mapHostGroup.Count -gt 0) {
                    $mappingContainsHostGroup = $true
                    Register-CleanupAction -Name 'Remove-DMHostGroupFromMappingView' -Action {
                        Invoke-MutationStep -Name 'Remove-DMHostGroupFromMappingView' -Action {
                            Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                            Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                            Remove-DMHostGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                                -HostGroupName $hostGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
            else {
                $dependencyStatus = if ($configuration.Host.Enabled) { 'Blocked' } else { 'NotConfigured' }
                $dependencyReason = if ($configuration.Host.Enabled) {
                    'Host-group mapping could not run because a test-owned host group or mapping view was not created successfully.'
                }
                else {
                    'Enable Host and Mapping workflows so both mapped resources are test-owned.'
                }
                Add-SkippedResult -Name @('Add-DMHostGroupToMappingView', 'Remove-DMHostGroupFromMappingView') `
                    -Status $dependencyStatus -Reason $dependencyReason
            }
            if ($owned.LunGroup.Contains($lunGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                $mapLunGroup = @(Invoke-MutationStep -Name 'Add-DMLunGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMLunGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -LunGroupName $lunGroupName -Confirm:$false
                })
                if ($mapLunGroup.Count -gt 0) {
                    $mappingContainsLunGroup = $true
                    Register-CleanupAction -Name 'Remove-DMLunGroupFromMappingView' -Action {
                        Invoke-MutationStep -Name 'Remove-DMLunGroupFromMappingView' -Action {
                            Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                            Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                            Remove-DMLunGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                                -LunGroupName $lunGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
            else {
                $dependencyStatus = if ($configuration.LunGroup.Enabled) { 'Blocked' } else { 'NotConfigured' }
                $dependencyReason = if ($configuration.LunGroup.Enabled) {
                    'LUN-group mapping could not run because a test-owned LUN group or mapping view was not created successfully.'
                }
                else {
                    'Enable LunGroup and Mapping workflows so both mapped resources are test-owned.'
                }
                Add-SkippedResult -Name @('Add-DMLunGroupToMappingView', 'Remove-DMLunGroupFromMappingView') `
                    -Status $dependencyStatus -Reason $dependencyReason
            }
            if ($owned.PortGroup.Contains($portGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                $mapPortGroup = @(Invoke-MutationStep -Name 'Add-DMPortGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMPortGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -PortGroupName $portGroupName -Confirm:$false
                })
                if ($mapPortGroup.Count -gt 0) {
                    $mappingContainsPortGroup = $true
                    Register-CleanupAction -Name 'Remove-DMPortGroupFromMappingView' -Action {
                        Invoke-MutationStep -Name 'Remove-DMPortGroupFromMappingView' -Action {
                            Assert-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                            Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                            Remove-DMPortGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                                -PortGroupName $portGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMPortGroup', 'Set-DMPortGroup', 'Rename-DMPortGroup', 'New-DMMappingView', 'Set-DMMappingView', 'Add-DMPortGroupToMappingView',
                'Remove-DMPortGroupFromMappingView', 'Add-DMHostGroupToMappingView',
                'Remove-DMHostGroupFromMappingView', 'Add-DMLunGroupToMappingView',
                'Remove-DMLunGroupFromMappingView', 'Remove-DMMappingView', 'Remove-DMPortGroup'
            ) -Status 'NotConfigured' -Reason 'Set Mapping.Enabled = $true to run the test-owned mapping view workflow.'
        }

}
