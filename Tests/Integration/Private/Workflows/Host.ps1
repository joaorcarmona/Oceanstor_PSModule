$script:HostMutationWorkflow = {
        if ($configuration.Host.Enabled) {
            $hostGroup = @(Invoke-MutationStep -Name 'New-DMHostGroup' -ExpectedType 'OceanStorHostGroup' -Action {
                if (@(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $hostGroupName).Count -gt 0) {
                    throw "A host group named '$hostGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMHostGroup -WebSession $session -Name $hostGroupName -Description "Integrity validation run $runId"
            })
            if ($hostGroup.Count -gt 0 -and $hostGroup[0].Name -eq $hostGroupName) {
                Register-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                Register-CleanupAction -Name 'Remove-DMHostGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMHostGroup' -Kind HostGroup -Identity $hostGroupName -Action {
                        Remove-DMHostGroup -WebSession $session -HostGroupName $hostGroupName -Confirm:$false
                    }
                }
            }
            if ($owned.HostGroup.Contains($hostGroupName)) {
                Invoke-MutationStep -Name 'Set-DMHostGroup' -Action {
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Set-DMHostGroup -WebSession $session -HostGroupName $hostGroupName `
                        -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMHostGroup:ReadBack' -ExpectedType 'OceanStorHostGroup' -Action {
                    $updated = @(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $hostGroupName)
                    if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMHostGroup description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                    }
                    $updated
                } | Out-Null
                $renameResult = @(Invoke-MutationStep -Name 'Rename-DMHostGroup' -Action {
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    if (@(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $renamedHostGroupName).Count -gt 0) {
                        throw "A host group named '$renamedHostGroupName' already exists; refusing to overwrite it."
                    }
                    Rename-DMHostGroup -WebSession $session -HostGroupName $hostGroupName `
                        -NewName $renamedHostGroupName -Confirm:$false
                })
                if ($renameResult.Count -gt 0) {
                    Update-TestOwnedResourceIdentity -Kind HostGroup -OldIdentity $hostGroupName -NewIdentity $renamedHostGroupName
                    $hostGroupName = $renamedHostGroupName
                    Add-MutationReadVerification -Name 'Rename-DMHostGroup:ReadBack' -ExpectedType 'OceanStorHostGroup' -Action {
                        Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $hostGroupName
                    } | Out-Null
                }
            }
            $createdHost = @(Invoke-MutationStep -Name 'New-DMHost' -ExpectedType 'OceanStorHost' -Action {
                if (@(Get-DMhost -WebSession $session | Where-Object Name -EQ $testHostName).Count -gt 0) {
                    throw "A host named '$testHostName' already exists; refusing to claim it as test-owned."
                }
                New-DMHost -WebSession $session -Name $testHostName -OperatingSystem $configuration.Host.OperatingSystem `
                    -Description "Integrity validation run $runId"
            })
            if ($createdHost.Count -gt 0 -and $createdHost[0].Name -eq $testHostName) {
                Register-TestOwnedResource -Kind Host -Identity $testHostName
                Register-CleanupAction -Name 'Remove-DMHost' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMHost' -Kind Host -Identity $testHostName -Action {
                        Remove-DMHost -WebSession $session -HostName $testHostName -Confirm:$false
                    }
                }
            }
            if ($owned.Host.Contains($testHostName)) {
                Invoke-MutationStep -Name 'Set-DMHost' -Action {
                    Assert-TestOwnedResource -Kind Host -Identity $testHostName
                    Set-DMHost -WebSession $session -HostName $testHostName `
                        -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMHost:ReadBack' -ExpectedType 'OceanStorHost' -Action {
                    $updated = @(Get-DMhost -WebSession $session | Where-Object Name -EQ $testHostName)
                    if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMHost description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                    }
                    $updated
                } | Out-Null
                $renameResult = @(Invoke-MutationStep -Name 'Rename-DMHost' -Action {
                    Assert-TestOwnedResource -Kind Host -Identity $testHostName
                    if (@(Get-DMhost -WebSession $session | Where-Object Name -EQ $renamedHostName).Count -gt 0) {
                        throw "A host named '$renamedHostName' already exists; refusing to overwrite it."
                    }
                    Rename-DMHost -WebSession $session -HostName $testHostName -NewName $renamedHostName -Confirm:$false
                })
                if ($renameResult.Count -gt 0) {
                    Update-TestOwnedResourceIdentity -Kind Host -OldIdentity $testHostName -NewIdentity $renamedHostName
                    $testHostName = $renamedHostName
                    Add-MutationReadVerification -Name 'Rename-DMHost:ReadBack' -ExpectedType 'OceanStorHost' -Action {
                        Get-DMhost -WebSession $session | Where-Object Name -EQ $testHostName
                    } | Out-Null
                }
            }
            if ($owned.Host.Contains($testHostName) -and $owned.HostGroup.Contains($hostGroupName)) {
                $hostAssociation = @(Invoke-MutationStep -Name 'Add-DMHostToHostGroup' -Action {
                    Assert-TestOwnedResource -Kind Host -Identity $testHostName
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Add-DMHostToHostGroup -WebSession $session -HostName $testHostName -HostGroupName $hostGroupName -Confirm:$false
                })
                if ($hostAssociation.Count -gt 0) {
                    $hostGroupContainsHost = $true
                    Register-CleanupAction -Name 'Remove-DMHostFromHostGroup' -Action {
                        Invoke-MutationStep -Name 'Remove-DMHostFromHostGroup' -Action {
                            Assert-TestOwnedResource -Kind Host -Identity $testHostName
                            Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                            Remove-DMHostFromHostGroup -WebSession $session -HostName $testHostName -HostGroupName $hostGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMHost', 'Set-DMHost', 'Rename-DMHost', 'New-DMHostGroup', 'Set-DMHostGroup', 'Rename-DMHostGroup', 'Add-DMHostToHostGroup',
                'Remove-DMHostFromHostGroup', 'Remove-DMHost', 'Remove-DMHostGroup'
            ) -Status 'NotConfigured' -Reason 'Set Host.Enabled = $true to run the test-owned host and host group workflow.'
        }

}
