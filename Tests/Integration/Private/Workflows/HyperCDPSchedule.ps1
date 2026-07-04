$script:HyperCDPScheduleMutationWorkflow = {
        if ($configuration.HyperCDPSchedule.Enabled) {
            if (-not $configuration.Lun.Enabled) {
                Add-SkippedResult -Name @(
                    'New-DMHyperCDPSchedule',
                    'Set-DMHyperCDPSchedule',
                    'Add-DMLunToHyperCDPSchedule',
                    'Remove-DMLunFromHyperCDPSchedule',
                    'Enable-DMHyperCDPSchedule',
                    'Disable-DMHyperCDPSchedule',
                    'Remove-DMHyperCDPSchedule'
                ) -Status 'NotConfigured' -Reason 'Set Lun.Enabled = $true so HyperCDP schedule validation can use a test-owned LUN.'
                return
            }

            if (-not $owned.Lun.Contains($lunName)) {
                Add-SkippedResult -Name @(
                    'New-DMHyperCDPSchedule',
                    'Set-DMHyperCDPSchedule',
                    'Add-DMLunToHyperCDPSchedule',
                    'Remove-DMLunFromHyperCDPSchedule',
                    'Enable-DMHyperCDPSchedule',
                    'Disable-DMHyperCDPSchedule',
                    'Remove-DMHyperCDPSchedule'
                ) -Status 'Blocked' -Reason 'The test-owned LUN was not created, so HyperCDP schedule association cannot be validated.'
                return
            }

            $hyperCdpSchedule = @(Invoke-MutationStep -Name 'New-DMHyperCDPSchedule' -ExpectedType 'OceanstorHyperCDPSchedule' -Action {
                if (@(Get-DMHyperCDPSchedule -WebSession $session -Name $hyperCdpScheduleName | Where-Object Name -EQ $hyperCdpScheduleName).Count -gt 0) {
                    throw "A HyperCDP schedule named '$hyperCdpScheduleName' already exists; refusing to claim it as test-owned."
                }
                New-DMHyperCDPSchedule -WebSession $session -Name $hyperCdpScheduleName `
                    -Description "Integrity validation run $runId" `
                    -FrequencyValueSeconds $configuration.HyperCDPSchedule.FrequencyValueSeconds `
                    -FrequencySnapshotCount $configuration.HyperCDPSchedule.FrequencySnapshotCount
            })
            if ($hyperCdpSchedule.Count -gt 0 -and $hyperCdpSchedule[0].Name -eq $hyperCdpScheduleName) {
                $hyperCdpScheduleId = $hyperCdpSchedule[0].Id
                Register-TestOwnedResource -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName
                Register-CleanupAction -Name 'Remove-DMHyperCDPSchedule' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMHyperCDPSchedule' -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName -Action {
                        if ($hyperCdpScheduleContainsLun) {
                            Remove-DMLunFromHyperCDPSchedule -WebSession $session -LunId $lunId -ScheduleId $hyperCdpScheduleId -Confirm:$false
                        }
                        Remove-DMHyperCDPSchedule -WebSession $session -ScheduleId $hyperCdpScheduleId -Confirm:$false
                    }
                }
            }

            if ($owned.HyperCDPSchedule.Contains($hyperCdpScheduleName)) {
                Add-MutationReadVerification -Name 'Get-DMHyperCDPSchedule:ById' -ExpectedType 'OceanstorHyperCDPSchedule' -Action {
                    Get-DMHyperCDPSchedule -WebSession $session -Id $hyperCdpScheduleId
                } | Out-Null
                Add-MutationReadVerification -Name 'Get-DMHyperCDPSchedule:ByName' -ExpectedType 'OceanstorHyperCDPSchedule' -Action {
                    Get-DMHyperCDPSchedule -WebSession $session -Name $hyperCdpScheduleName | Where-Object Name -EQ $hyperCdpScheduleName
                } | Out-Null

                Invoke-MutationStep -Name 'Set-DMHyperCDPSchedule' -Action {
                    Assert-TestOwnedResource -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName
                    Set-DMHyperCDPSchedule -WebSession $session -ScheduleId $hyperCdpScheduleId `
                        -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMHyperCDPSchedule:ReadBack' -ExpectedType 'OceanstorHyperCDPSchedule' -Action {
                    $updated = @(Get-DMHyperCDPSchedule -WebSession $session -Id $hyperCdpScheduleId)
                    if ($updated.Count -gt 0 -and $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMHyperCDPSchedule description mismatch: expected 'Integrity validation updated $runId', got '$($updated[0].Description)'."
                    }
                    $updated
                } | Out-Null

                Invoke-MutationStep -Name 'Add-DMLunToHyperCDPSchedule' -Action {
                    Assert-TestOwnedResource -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Add-DMLunToHyperCDPSchedule -WebSession $session -LunId $lunId -ScheduleId $hyperCdpScheduleId -Confirm:$false
                } | Out-Null
                $hyperCdpScheduleContainsLun = $true
                Add-MutationReadVerification -Name 'Add-DMLunToHyperCDPSchedule:ReadBack' -Action {
                    $updatedLun = @(Get-DMlun -WebSession $session -Id $lunId)
                    if ($updatedLun.Count -gt 0 -and $updatedLun[0].'HyperCDP Schedule Id' -ne $hyperCdpScheduleId) {
                        throw "Expected LUN '$lunName' to reference HyperCDP schedule '$hyperCdpScheduleId', got '$($updatedLun[0].'HyperCDP Schedule Id')'."
                    }
                    $updatedLun
                } | Out-Null

                Invoke-MutationStep -Name 'Remove-DMLunFromHyperCDPSchedule' -Action {
                    Assert-TestOwnedResource -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Remove-DMLunFromHyperCDPSchedule -WebSession $session -LunId $lunId -ScheduleId $hyperCdpScheduleId -Confirm:$false
                } | Out-Null
                $hyperCdpScheduleContainsLun = $false
                Add-MutationReadVerification -Name 'Remove-DMLunFromHyperCDPSchedule:ReadBack' -Action {
                    $updatedLun = @(Get-DMlun -WebSession $session -Id $lunId)
                    if ($updatedLun.Count -gt 0 -and $updatedLun[0].'HyperCDP Schedule Id' -eq $hyperCdpScheduleId) {
                        throw "Expected LUN '$lunName' to be removed from HyperCDP schedule '$hyperCdpScheduleId'."
                    }
                    $updatedLun
                } | Out-Null

                Invoke-MutationStep -Name 'Enable-DMHyperCDPSchedule' -Action {
                    Assert-TestOwnedResource -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName
                    Enable-DMHyperCDPSchedule -WebSession $session -ScheduleId $hyperCdpScheduleId -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Enable-DMHyperCDPSchedule:ReadBack' -ExpectedType 'OceanstorHyperCDPSchedule' -Action {
                    $enabled = @(Get-DMHyperCDPSchedule -WebSession $session -Id $hyperCdpScheduleId)
                    if ($enabled.Count -gt 0 -and -not $enabled[0].Enabled) {
                        throw "Expected HyperCDP schedule '$hyperCdpScheduleName' to be enabled."
                    }
                    $enabled
                } | Out-Null

                Invoke-MutationStep -Name 'Disable-DMHyperCDPSchedule' -Action {
                    Assert-TestOwnedResource -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName
                    Disable-DMHyperCDPSchedule -WebSession $session -ScheduleId $hyperCdpScheduleId -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Disable-DMHyperCDPSchedule:ReadBack' -ExpectedType 'OceanstorHyperCDPSchedule' -Action {
                    $disabled = @(Get-DMHyperCDPSchedule -WebSession $session -Id $hyperCdpScheduleId)
                    if ($disabled.Count -gt 0 -and $disabled[0].Enabled) {
                        throw "Expected HyperCDP schedule '$hyperCdpScheduleName' to be disabled."
                    }
                    $disabled
                } | Out-Null

                $removeResult = @(Invoke-MutationStep -Name 'Remove-DMHyperCDPSchedule' -Action {
                    Assert-TestOwnedResource -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName
                    Remove-DMHyperCDPSchedule -WebSession $session -ScheduleId $hyperCdpScheduleId -Confirm:$false
                })
                if ($removeResult.Count -gt 0) {
                    Complete-TestOwnedResource -Kind HyperCDPSchedule -Identity $hyperCdpScheduleName
                }
                Add-ValidationResult -Name 'Verify:Remove-DMHyperCDPSchedule:ReadBack' -Category 'MutationRead' -Action {
                    $removed = @(Get-DMHyperCDPSchedule -WebSession $session -Filter ID -Value $hyperCdpScheduleId)
                    if ($removed.Count -gt 0) {
                        throw "HyperCDP schedule '$hyperCdpScheduleName' still exists after removal."
                    }
                    [pscustomobject]@{ Removed = $true }
                } | Out-Null
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMHyperCDPSchedule',
                'Set-DMHyperCDPSchedule',
                'Add-DMLunToHyperCDPSchedule',
                'Remove-DMLunFromHyperCDPSchedule',
                'Enable-DMHyperCDPSchedule',
                'Disable-DMHyperCDPSchedule',
                'Remove-DMHyperCDPSchedule'
            ) -Status 'NotConfigured' -Reason 'Set HyperCDPSchedule.Enabled = $true to run non-secure HyperCDP schedule mutation coverage.'
        }
}
