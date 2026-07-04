$script:QosMutationWorkflow = {
    $qosCommandNames = @(
        'New-DMQosPolicy',
        'Set-DMQosPolicy',
        'Disable-DMQosPolicy',
        'Enable-DMQosPolicy',
        'Add-DMQosAssociation',
        'Remove-DMQosAssociation',
        'Remove-DMQosPolicy'
    )

    if ($configuration.QoS.Enabled -and $owned.Lun.Contains($lunName) -and $lunGroupContainsLun) {
        $qosPolicy = @(Invoke-MutationStep -Name 'New-DMQosPolicy' -ExpectedType 'OceanstorQosPolicy' -Action {
            Assert-TestOwnedResource -Kind Lun -Identity $lunName
            if (@(Get-DMQosPolicy -WebSession $session -Name $qosPolicyName | Where-Object Name -EQ $qosPolicyName).Count -gt 0) {
                throw "A SmartQoS policy named '$qosPolicyName' already exists; refusing to claim it as test-owned."
            }
            New-DMQosPolicy -WebSession $session -Name $qosPolicyName -Description "Integrity validation run $runId" `
                -MaxIOPS 1000 -LunName $lunName -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600
        })
        if ($qosPolicy.Count -gt 0 -and $qosPolicy[0].Name -eq $qosPolicyName) {
            Register-TestOwnedResource -Kind QosPolicy -Identity $qosPolicyName
            Register-CleanupAction -Name 'Remove-DMQosPolicy' -Action {
                Invoke-OwnedRemoval -Name 'Remove-DMQosPolicy' -Kind QosPolicy -Identity $qosPolicyName -Action {
                    Remove-DMQosPolicy -WebSession $session -Name $qosPolicyName -Confirm:$false
                }
            }
        }

        if ($owned.QosPolicy.Contains($qosPolicyName)) {
            Add-MutationReadVerification -Name 'New-DMQosPolicy:ReadBack' -ExpectedType 'OceanstorQosPolicy' -Action {
                Get-DMQosPolicy -WebSession $session -Name $qosPolicyName | Where-Object Name -EQ $qosPolicyName
            } | Out-Null

            $renameResult = @(Invoke-MutationStep -Name 'Set-DMQosPolicy' -Action {
                Assert-TestOwnedResource -Kind QosPolicy -Identity $qosPolicyName
                if (@(Get-DMQosPolicy -WebSession $session -Name $renamedQosPolicyName | Where-Object Name -EQ $renamedQosPolicyName).Count -gt 0) {
                    throw "A SmartQoS policy named '$renamedQosPolicyName' already exists; refusing to overwrite it."
                }
                Set-DMQosPolicy -WebSession $session -Name $qosPolicyName -NewName $renamedQosPolicyName `
                    -Description "Integrity validation updated $runId" -MaxIOPS 1500 -Confirm:$false
            })
            if ($renameResult.Count -gt 0) {
                Update-TestOwnedResourceIdentity -Kind QosPolicy -OldIdentity $qosPolicyName -NewIdentity $renamedQosPolicyName
                $qosPolicyName = $renamedQosPolicyName

                Add-MutationReadVerification -Name 'Set-DMQosPolicy:ReadBack' -ExpectedType 'OceanstorQosPolicy' -Action {
                    $updated = @(Get-DMQosPolicy -WebSession $session -Name $qosPolicyName | Where-Object Name -EQ $qosPolicyName)
                    if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMQosPolicy description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                    }
                    if ($updated.Count -gt 0 -and $updated[0].'Max IOPS' -ne 1500) {
                        throw "Set-DMQosPolicy Max IOPS mismatch: expected 1500, got '$($updated[0].'Max IOPS')'."
                    }
                    $updated
                } | Out-Null
            }
            else {
                Add-SkippedResult -Name @(
                    'Disable-DMQosPolicy',
                    'Enable-DMQosPolicy',
                    'Add-DMQosAssociation',
                    'Remove-DMQosAssociation'
                ) -Status 'Blocked' -Reason 'Set-DMQosPolicy did not complete, so subsequent SmartQoS mutation steps were skipped.'
                return
            }

            Invoke-MutationStep -Name 'Disable-DMQosPolicy' -Action {
                Assert-TestOwnedResource -Kind QosPolicy -Identity $qosPolicyName
                Disable-DMQosPolicy -WebSession $session -Name $qosPolicyName -Confirm:$false
            } | Out-Null
            Add-MutationReadVerification -Name 'Disable-DMQosPolicy:ReadBack' -ExpectedType 'OceanstorQosPolicy' -Action {
                $updated = @(Get-DMQosPolicy -WebSession $session -Name $qosPolicyName | Where-Object Name -EQ $qosPolicyName)
                if ($updated.Count -gt 0 -and $updated[0].Enabled) {
                    throw "Disable-DMQosPolicy did not set Enabled to false."
                }
                $updated
            } | Out-Null

            Invoke-MutationStep -Name 'Enable-DMQosPolicy' -Action {
                Assert-TestOwnedResource -Kind QosPolicy -Identity $qosPolicyName
                Enable-DMQosPolicy -WebSession $session -Name $qosPolicyName -Confirm:$false
            } | Out-Null
            Add-MutationReadVerification -Name 'Enable-DMQosPolicy:ReadBack' -ExpectedType 'OceanstorQosPolicy' -Action {
                $updated = @(Get-DMQosPolicy -WebSession $session -Name $qosPolicyName | Where-Object Name -EQ $qosPolicyName)
                if ($updated.Count -gt 0 -and -not $updated[0].Enabled) {
                    throw "Enable-DMQosPolicy did not set Enabled to true."
                }
                $updated
            } | Out-Null

            $association = @(Invoke-MutationStep -Name 'Add-DMQosAssociation' -Action {
                Assert-TestOwnedResource -Kind QosPolicy -Identity $qosPolicyName
                Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                Add-DMQosAssociation -WebSession $session -Name $qosPolicyName -LunGroupName $lunGroupName -Confirm:$false
            })
            if ($association.Count -gt 0) {
                Register-CleanupAction -Name 'Remove-DMQosAssociation' -Action {
                    Invoke-MutationStep -Name 'Remove-DMQosAssociation' -Action {
                        Assert-TestOwnedResource -Kind QosPolicy -Identity $qosPolicyName
                        Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                        Remove-DMQosAssociation -WebSession $session -Name $qosPolicyName -LunGroupName $lunGroupName -Confirm:$false
                    } | Out-Null
                }
            }
        }
    }
    elseif (-not $configuration.QoS.Enabled) {
        Add-SkippedResult -Name $qosCommandNames -Status 'NotConfigured' -Reason 'Set QoS.Enabled = $true with Lun and LunGroup enabled to run the test-owned SmartQoS workflow.'
    }
    else {
        Add-SkippedResult -Name $qosCommandNames -Status 'Blocked' -Reason 'SmartQoS validation could not run because the test-owned LUN and LUN-group association was not created successfully.'
    }
}
