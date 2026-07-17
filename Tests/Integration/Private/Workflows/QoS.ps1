$script:QosMutationWorkflow = {
    $qosCommandNames = @(
        'New-DMQosPolicy',
        'Set-DMQosPolicy',
        'Stop-DMQosPolicy',
        'Start-DMQosPolicy',
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
            # A 'Once' policy window must be in the future or the array rejects it as overdue
            # (API 1077950863), so schedule the effective date one day ahead.
            # The policy is created WITHOUT a LUN binding: a SmartQoS policy can bind to exactly
            # one object type, and this workflow validates the LUN-group association path below
            # (Add-DMQosAssociation). Binding a LUN here makes that association conflict, which
            # the cmdlet's pre-validation (correctly) rejects.
            New-DMQosPolicy -WebSession $session -Name $qosPolicyName -Description "Integrity validation run $runId" `
                -MaxIOPS 1000 -ScheduleStartTime (Get-Date).AddDays(1) -StartTime '00:00' -Duration 3600
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
                $created = @(Get-DMQosPolicy -WebSession $session -Name $qosPolicyName | Where-Object Name -EQ $qosPolicyName)
                # Schedule Start Time is now surfaced as a human-readable [datetime] (converted from the
                # array's raw UTC epoch seconds), not the raw number. Assert the new type on read-back.
                if ($created.Count -gt 0 -and $created[0].'Schedule Start Time' -isnot [datetime]) {
                    throw "New-DMQosPolicy 'Schedule Start Time' should be [datetime], got '$($created[0].'Schedule Start Time'.GetType().Name)'."
                }
                $created
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
                    'Stop-DMQosPolicy',
                    'Start-DMQosPolicy',
                    'Add-DMQosAssociation',
                    'Remove-DMQosAssociation'
                ) -Status 'Blocked' -Reason 'Set-DMQosPolicy did not complete, so subsequent SmartQoS mutation steps were skipped.'
                return
            }

            Invoke-MutationStep -Name 'Stop-DMQosPolicy' -Action {
                Assert-TestOwnedResource -Kind QosPolicy -Identity $qosPolicyName
                Stop-DMQosPolicy -WebSession $session -Name $qosPolicyName -Confirm:$false
            } | Out-Null
            Add-MutationReadVerification -Name 'Stop-DMQosPolicy:ReadBack' -ExpectedType 'OceanstorQosPolicy' -Action {
                # Stop deactivates the policy: it drives Running Status to 'Inactive' (it does NOT
                # change ENABLESTATUS/Enabled). The array applies this asynchronously (the PUT
                # returns success before Running Status settles), so poll for 'Inactive' up to a
                # bounded timeout before asserting instead of reading back immediately.
                $deadline = (Get-Date).AddSeconds(30)
                do {
                    $updated = @(Get-DMQosPolicy -WebSession $session -Name $qosPolicyName | Where-Object Name -EQ $qosPolicyName)
                    if ($updated.Count -gt 0 -and $updated[0].'Running Status' -eq 'Inactive') { break }
                    Start-Sleep -Seconds 2
                } while ((Get-Date) -lt $deadline)
                if ($updated.Count -gt 0 -and $updated[0].'Running Status' -ne 'Inactive') {
                    throw "Stop-DMQosPolicy did not set Running Status to 'Inactive' within 30s (got '$($updated[0].'Running Status')')."
                }
                $updated
            } | Out-Null

            Invoke-MutationStep -Name 'Start-DMQosPolicy' -Action {
                Assert-TestOwnedResource -Kind QosPolicy -Identity $qosPolicyName
                Start-DMQosPolicy -WebSession $session -Name $qosPolicyName -Confirm:$false
            } | Out-Null
            Add-MutationReadVerification -Name 'Start-DMQosPolicy:ReadBack' -ExpectedType 'OceanstorQosPolicy' -Action {
                # Start activates the policy: it drives Running Status away from 'Inactive' to
                # 'Idle' (or 'Running' when inside the schedule window / associated). It does NOT
                # change ENABLESTATUS/Enabled. Same asynchronous settle as the Disable read-back:
                # poll for a non-'Inactive' Running Status up to a bounded timeout before asserting.
                $deadline = (Get-Date).AddSeconds(30)
                do {
                    $updated = @(Get-DMQosPolicy -WebSession $session -Name $qosPolicyName | Where-Object Name -EQ $qosPolicyName)
                    if ($updated.Count -gt 0 -and $updated[0].'Running Status' -ne 'Inactive') { break }
                    Start-Sleep -Seconds 2
                } while ((Get-Date) -lt $deadline)
                if ($updated.Count -gt 0 -and $updated[0].'Running Status' -eq 'Inactive') {
                    throw "Start-DMQosPolicy did not start the policy (Running Status still 'Inactive') within 30s."
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
