$script:HyperMetroMutationWorkflow = {
        $hyperMetroCommandNames = @(
            'Get-DMRemoteDevice', 'Get-DMRemoteLun', 'Get-DMHyperMetroDomain',
            'New-DMHyperMetroPair', 'Get-DMHyperMetroPair', 'Sync-DMHyperMetroPair',
            'Suspend-DMHyperMetroPair', 'Start-DMHyperMetroPair',
            'Switch-DMHyperMetroPairPriority', 'Remove-DMHyperMetroPair',
            'New-DMHyperMetroConsistencyGroup', 'Get-DMHyperMetroConsistencyGroup',
            'Set-DMHyperMetroConsistencyGroup', 'Add-DMHyperMetroPairToConsistencyGroup',
            'Remove-DMHyperMetroPairFromConsistencyGroup', 'Sync-DMHyperMetroConsistencyGroup',
            'Suspend-DMHyperMetroConsistencyGroup', 'Start-DMHyperMetroConsistencyGroup',
            'Switch-DMHyperMetroConsistencyGroup', 'Remove-DMHyperMetroConsistencyGroup'
        )

        if (-not $configuration.HyperMetro.Enabled) {
            Add-SkippedResult -Name $hyperMetroCommandNames -Status 'NotConfigured' `
                -Reason 'Set HyperMetro.Enabled and HyperMetro.AllowDrMutation to true with remote device, remote LUN, and domain configuration to run the HyperMetro workflow.'
            return
        }

        if (-not $owned.Lun.Contains($lunName)) {
            Add-SkippedResult -Name $hyperMetroCommandNames -Status 'Blocked' `
                -Reason 'HyperMetro validation requires the test-owned local LUN created by the LUN workflow.'
            return
        }

        $hyperMetroGroupName = New-TestName -Suffix 'hmcg'
        $hyperMetroPairId = $null
        $hyperMetroGroupId = $null
        $hyperMetroPairInGroup = $false

        $remoteDeviceId = if ($configuration.HyperMetro.RemoteDeviceId) {
            $configuration.HyperMetro.RemoteDeviceId
        }
        else {
            $remoteDevice = @(Add-MutationReadVerification -Name 'Get-DMRemoteDevice:HyperMetro' -ExpectedType 'OceanstorRemoteDevice' -Action {
                Get-DMRemoteDevice -WebSession $session -Name $configuration.HyperMetro.RemoteDeviceName |
                    Where-Object Name -EQ $configuration.HyperMetro.RemoteDeviceName
            })
            if ($remoteDevice.Count -eq 0) { return }
            $remoteDevice[0].Id
        }

        $remoteLunId = if ($configuration.HyperMetro.RemoteLunId) {
            $configuration.HyperMetro.RemoteLunId
        }
        else {
            $remoteLun = @(Add-MutationReadVerification -Name 'Get-DMRemoteLun:HyperMetro' -ExpectedType 'OceanstorRemoteLun' -Action {
                Get-DMRemoteLun -WebSession $session -RemoteDeviceId $remoteDeviceId `
                    -RemoteServiceType $configuration.HyperMetro.RemoteServiceType -Name $configuration.HyperMetro.RemoteLunName |
                    Where-Object Name -EQ $configuration.HyperMetro.RemoteLunName
            })
            if ($remoteLun.Count -eq 0) { return }
            $remoteLun[0].'Remote Lun Id'
        }

        $domainId = if ($configuration.HyperMetro.DomainId) {
            $configuration.HyperMetro.DomainId
        }
        else {
            $domain = @(Add-MutationReadVerification -Name 'Get-DMHyperMetroDomain:Configured' -ExpectedType 'OceanstorHyperMetroDomain' -Action {
                Get-DMHyperMetroDomain -WebSession $session -Name $configuration.HyperMetro.DomainName |
                    Where-Object Name -EQ $configuration.HyperMetro.DomainName
            })
            if ($domain.Count -eq 0) { return }
            $domain[0].Id
        }

        $hyperMetroPair = @(Invoke-MutationStep -Name 'New-DMHyperMetroPair' -ExpectedType 'OceanstorHyperMetroPair' -Action {
            Assert-TestOwnedResource -Kind Lun -Identity $lunName
            New-DMHyperMetroPair -WebSession $session -DomainId $domainId -LocalLunId $lunId `
                -RemoteLunId $remoteLunId -FirstSync -RecoveryPolicy Manual -Speed Low
        })
        if ($hyperMetroPair.Count -gt 0) {
            $hyperMetroPairId = $hyperMetroPair[0].Id
            Register-TestOwnedResource -Kind HyperMetroPair -Identity $hyperMetroPairId
            Register-CleanupAction -Name 'Remove-DMHyperMetroPair' -Action {
                Invoke-OwnedRemoval -Name 'Remove-DMHyperMetroPair' -Kind HyperMetroPair -Identity $hyperMetroPairId -Action {
                    Remove-DMHyperMetroPair -WebSession $session -Id $hyperMetroPairId -Confirm:$false
                }
            }
        }

        if ($owned.HyperMetroPair.Contains($hyperMetroPairId)) {
            Add-MutationReadVerification -Name 'Get-DMHyperMetroPair:Created' -ExpectedType 'OceanstorHyperMetroPair' -Action {
                Get-DMHyperMetroPair -WebSession $session -Id $hyperMetroPairId
            } | Out-Null

            Invoke-MutationStep -Name 'Sync-DMHyperMetroPair' -Action {
                Assert-TestOwnedResource -Kind HyperMetroPair -Identity $hyperMetroPairId
                Sync-DMHyperMetroPair -WebSession $session -Id $hyperMetroPairId -Confirm:$false
            } | Out-Null

            Invoke-MutationStep -Name 'Suspend-DMHyperMetroPair' -Action {
                Assert-TestOwnedResource -Kind HyperMetroPair -Identity $hyperMetroPairId
                Suspend-DMHyperMetroPair -WebSession $session -Id $hyperMetroPairId -Confirm:$false
            } | Out-Null

            Invoke-MutationStep -Name 'Start-DMHyperMetroPair' -Action {
                Assert-TestOwnedResource -Kind HyperMetroPair -Identity $hyperMetroPairId
                Start-DMHyperMetroPair -WebSession $session -Id $hyperMetroPairId -Confirm:$false
            } | Out-Null

            if ($configuration.HyperMetro.AllowPrioritySwitch) {
                Invoke-MutationStep -Name 'Switch-DMHyperMetroPairPriority' -Action {
                    Assert-TestOwnedResource -Kind HyperMetroPair -Identity $hyperMetroPairId
                    Switch-DMHyperMetroPairPriority -WebSession $session -Id $hyperMetroPairId -Confirm:$false
                } | Out-Null
            }
            else {
                Add-SkippedResult -Name 'Switch-DMHyperMetroPairPriority' -Status 'SkippedUnsafe' `
                    -Reason 'Set HyperMetro.AllowPrioritySwitch = $true only in a lab where priority switching is expected.'
            }

            $hyperMetroGroup = @(Invoke-MutationStep -Name 'New-DMHyperMetroConsistencyGroup' -ExpectedType 'OceanstorHyperMetroConsistencyGroup' -Action {
                if (@(Get-DMHyperMetroConsistencyGroup -WebSession $session -Name $hyperMetroGroupName | Where-Object Name -EQ $hyperMetroGroupName).Count -gt 0) {
                    throw "A HyperMetro consistency group named '$hyperMetroGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMHyperMetroConsistencyGroup -WebSession $session -Name $hyperMetroGroupName `
                    -DomainId $domainId -RecoveryPolicy Manual -Speed Low
            })
            if ($hyperMetroGroup.Count -gt 0 -and $hyperMetroGroup[0].Name -eq $hyperMetroGroupName) {
                $hyperMetroGroupId = $hyperMetroGroup[0].Id
                Register-TestOwnedResource -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId
                Register-CleanupAction -Name 'Remove-DMHyperMetroConsistencyGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMHyperMetroConsistencyGroup' -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId -Action {
                        Remove-DMHyperMetroConsistencyGroup -WebSession $session -Id $hyperMetroGroupId -Confirm:$false
                    }
                }
            }
        }

        if ($owned.HyperMetroConsistencyGroup.Contains($hyperMetroGroupId)) {
            Invoke-MutationStep -Name 'Set-DMHyperMetroConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId
                Set-DMHyperMetroConsistencyGroup -WebSession $session -Id $hyperMetroGroupId `
                    -Description "Integrity validation updated $runId" -Confirm:$false
            } | Out-Null

            Invoke-MutationStep -Name 'Add-DMHyperMetroPairToConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId
                Assert-TestOwnedResource -Kind HyperMetroPair -Identity $hyperMetroPairId
                Add-DMHyperMetroPairToConsistencyGroup -WebSession $session -GroupId $hyperMetroGroupId `
                    -PairId $hyperMetroPairId -Confirm:$false
            } | Out-Null
            $hyperMetroPairInGroup = $true
            Register-CleanupAction -Name 'Remove-DMHyperMetroPairFromConsistencyGroup:Cleanup' -Action {
                if ($hyperMetroPairInGroup -and $owned.HyperMetroConsistencyGroup.Contains($hyperMetroGroupId) -and $owned.HyperMetroPair.Contains($hyperMetroPairId)) {
                    Invoke-MutationStep -Name 'Remove-DMHyperMetroPairFromConsistencyGroup:Cleanup' -Action {
                        Remove-DMHyperMetroPairFromConsistencyGroup -WebSession $session -GroupId $hyperMetroGroupId `
                            -PairId $hyperMetroPairId -Confirm:$false
                    } | Out-Null
                }
            }

            Add-MutationReadVerification -Name 'Get-DMHyperMetroConsistencyGroup:Created' -ExpectedType 'OceanstorHyperMetroConsistencyGroup' -Action {
                Get-DMHyperMetroConsistencyGroup -WebSession $session -Id $hyperMetroGroupId
            } | Out-Null

            Invoke-MutationStep -Name 'Sync-DMHyperMetroConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId
                Sync-DMHyperMetroConsistencyGroup -WebSession $session -Id $hyperMetroGroupId -Confirm:$false
            } | Out-Null

            Invoke-MutationStep -Name 'Suspend-DMHyperMetroConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId
                Suspend-DMHyperMetroConsistencyGroup -WebSession $session -Id $hyperMetroGroupId -Confirm:$false
            } | Out-Null

            Invoke-MutationStep -Name 'Start-DMHyperMetroConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId
                Start-DMHyperMetroConsistencyGroup -WebSession $session -Id $hyperMetroGroupId -Confirm:$false
            } | Out-Null

            if ($configuration.HyperMetro.AllowPrioritySwitch) {
                Invoke-MutationStep -Name 'Switch-DMHyperMetroConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId
                    Switch-DMHyperMetroConsistencyGroup -WebSession $session -Id $hyperMetroGroupId -Confirm:$false
                } | Out-Null
            }
            else {
                Add-SkippedResult -Name 'Switch-DMHyperMetroConsistencyGroup' -Status 'SkippedUnsafe' `
                    -Reason 'Set HyperMetro.AllowPrioritySwitch = $true only in a lab where group switching is expected.'
            }

            Invoke-MutationStep -Name 'Remove-DMHyperMetroPairFromConsistencyGroup' -Action {
                Assert-TestOwnedResource -Kind HyperMetroConsistencyGroup -Identity $hyperMetroGroupId
                Assert-TestOwnedResource -Kind HyperMetroPair -Identity $hyperMetroPairId
                Remove-DMHyperMetroPairFromConsistencyGroup -WebSession $session -GroupId $hyperMetroGroupId `
                    -PairId $hyperMetroPairId -Confirm:$false
            } | Out-Null
            $hyperMetroPairInGroup = $false
        }

}
