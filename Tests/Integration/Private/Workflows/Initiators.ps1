$script:InitiatorsMutationWorkflow = {
        if ($configuration.Initiators.Enabled) {
            if ($configuration.Initiators.FibreChannelWWN) {
                $fc = @(Invoke-MutationStep -Name 'New-DMFiberChannelInitiator' -ExpectedType 'OceanstorHostinitiatorFC' -Action {
                    if (@(Get-DMFiberChannelInitiator -WebSession $session | Where-Object Id -EQ $configuration.Initiators.FibreChannelWWN).Count -gt 0) {
                        throw 'The configured Fibre Channel WWN already exists; refusing to modify it.'
                    }
                    if ($owned.Host.Contains($testHostName)) {
                        Assert-TestOwnedResource -Kind Host -Identity $testHostName
                        New-DMFiberChannelInitiator -WebSession $session -WWN $configuration.Initiators.FibreChannelWWN -HostName $testHostName
                    }
                    else {
                        New-DMFiberChannelInitiator -WebSession $session -WWN $configuration.Initiators.FibreChannelWWN
                    }
                })
                if ($fc.Count -gt 0 -and $fc[0].Id -eq $configuration.Initiators.FibreChannelWWN) {
                    Register-TestOwnedResource -Kind FibreChannelInitiator -Identity $configuration.Initiators.FibreChannelWWN
                    Register-CleanupAction -Name 'Remove-DMFiberChannelInitiator' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMFiberChannelInitiator' -Kind FibreChannelInitiator `
                            -Identity $configuration.Initiators.FibreChannelWWN -Action {
                                Remove-DMFiberChannelInitiator -WebSession $session -WWN $configuration.Initiators.FibreChannelWWN -Confirm:$false
                            }
                    }
                }
                if ($owned.Host.Contains($testHostName) -and $owned.FibreChannelInitiator.Contains($configuration.Initiators.FibreChannelWWN)) {
                    Register-CleanupAction -Name 'Remove-DMFiberChannelInitiatorFromHost' -Action {
                        Invoke-MutationStep -Name 'Remove-DMFiberChannelInitiatorFromHost' -Action {
                            Assert-TestOwnedResource -Kind Host -Identity $testHostName
                            Assert-TestOwnedResource -Kind FibreChannelInitiator -Identity $configuration.Initiators.FibreChannelWWN
                            Remove-DMFiberChannelInitiatorFromHost -WebSession $session -HostName $testHostName `
                                -WWN $configuration.Initiators.FibreChannelWWN -Confirm:$false
                        } | Out-Null
                    }
                }
                else {
                    $detachStatus = if ($configuration.Host.Enabled) { 'Blocked' } else { 'NotConfigured' }
                    $detachReason = if ($configuration.Host.Enabled) {
                        'FC detachment could not run because the test-owned host or FC initiator was not created successfully.'
                    }
                    else {
                        'Set Host.Enabled = $true so the FC initiator can be attached to and removed from a test-owned host.'
                    }
                    Add-SkippedResult -Name 'Remove-DMFiberChannelInitiatorFromHost' -Status $detachStatus `
                        -Reason $detachReason
                }
            }
            else {
                Add-SkippedResult -Name @('New-DMFiberChannelInitiator', 'Remove-DMFiberChannelInitiatorFromHost', 'Remove-DMFiberChannelInitiator') `
                    -Status 'NotConfigured' -Reason 'Provide Initiators.FibreChannelWWN to validate a free FC initiator lifecycle.'
            }
            if ($configuration.Initiators.IscsiIdentifier) {
                $iscsi = @(Invoke-MutationStep -Name 'New-DMIscsiInitiator' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
                    if (@(Get-DMIscsiInitiator -WebSession $session | Where-Object Id -EQ $configuration.Initiators.IscsiIdentifier).Count -gt 0) {
                        throw 'The configured iSCSI identifier already exists; refusing to modify it.'
                    }
                    if ($owned.Host.Contains($testHostName)) {
                        Assert-TestOwnedResource -Kind Host -Identity $testHostName
                        New-DMIscsiInitiator -WebSession $session -Identifier $configuration.Initiators.IscsiIdentifier -HostName $testHostName
                    }
                    else {
                        New-DMIscsiInitiator -WebSession $session -Identifier $configuration.Initiators.IscsiIdentifier
                    }
                })
                if ($iscsi.Count -gt 0 -and $iscsi[0].Id -eq $configuration.Initiators.IscsiIdentifier) {
                    Register-TestOwnedResource -Kind IscsiInitiator -Identity $configuration.Initiators.IscsiIdentifier
                    Register-CleanupAction -Name 'Remove-DMIscsiInitiator' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMIscsiInitiator' -Kind IscsiInitiator `
                            -Identity $configuration.Initiators.IscsiIdentifier -Action {
                                Remove-DMIscsiInitiator -WebSession $session -Identifier $configuration.Initiators.IscsiIdentifier -Confirm:$false
                            }
                    }
                }
                if ($owned.Host.Contains($testHostName) -and $owned.IscsiInitiator.Contains($configuration.Initiators.IscsiIdentifier)) {
                    Register-CleanupAction -Name 'Remove-DMIscsiInitiatorFromHost' -Action {
                        Invoke-MutationStep -Name 'Remove-DMIscsiInitiatorFromHost' -Action {
                            Assert-TestOwnedResource -Kind Host -Identity $testHostName
                            Assert-TestOwnedResource -Kind IscsiInitiator -Identity $configuration.Initiators.IscsiIdentifier
                            Remove-DMIscsiInitiatorFromHost -WebSession $session -HostName $testHostName `
                                -Identifier $configuration.Initiators.IscsiIdentifier -Confirm:$false
                        } | Out-Null
                    }
                }
                else {
                    $detachStatus = if ($configuration.Host.Enabled) { 'Blocked' } else { 'NotConfigured' }
                    $detachReason = if ($configuration.Host.Enabled) {
                        'iSCSI detachment could not run because the test-owned host or iSCSI initiator was not created successfully.'
                    }
                    else {
                        'Set Host.Enabled = $true so the iSCSI initiator can be attached to and removed from a test-owned host.'
                    }
                    Add-SkippedResult -Name 'Remove-DMIscsiInitiatorFromHost' -Status $detachStatus `
                        -Reason $detachReason
                }
            }
            else {
                Add-SkippedResult -Name @('New-DMIscsiInitiator', 'Remove-DMIscsiInitiatorFromHost', 'Remove-DMIscsiInitiator') `
                    -Status 'NotConfigured' -Reason 'Provide Initiators.IscsiIdentifier to validate a free iSCSI initiator lifecycle.'
            }
            if ($configuration.Initiators.NvmeNqn) {
                $nvme = @(Invoke-MutationStep -Name 'New-DMNvmeInitiator' -ExpectedType 'OceanstorHostinitiatorNVMe' -Action {
                    if (@(Get-DMNvmeInitiator -WebSession $session | Where-Object Id -EQ $configuration.Initiators.NvmeNqn).Count -gt 0) {
                        throw 'The configured NVMe NQN already exists; refusing to modify it.'
                    }
                    New-DMNvmeInitiator -WebSession $session -Nqn $configuration.Initiators.NvmeNqn
                })
                if ($nvme.Count -gt 0 -and $nvme[0].Id -eq $configuration.Initiators.NvmeNqn) {
                    Register-TestOwnedResource -Kind NvmeInitiator -Identity $configuration.Initiators.NvmeNqn
                    Register-CleanupAction -Name 'Remove-DMNvmeInitiator' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMNvmeInitiator' -Kind NvmeInitiator `
                            -Identity $configuration.Initiators.NvmeNqn -Action {
                                Remove-DMNvmeInitiator -WebSession $session -Nqn $configuration.Initiators.NvmeNqn -Confirm:$false
                            }
                    }
                }
            }
            else {
                Add-SkippedResult -Name @('New-DMNvmeInitiator', 'Remove-DMNvmeInitiator') `
                    -Status 'NotConfigured' -Reason 'Provide Initiators.NvmeNqn to validate a free NVMe initiator lifecycle.'
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMFiberChannelInitiator', 'Remove-DMFiberChannelInitiatorFromHost', 'Remove-DMFiberChannelInitiator',
                'New-DMIscsiInitiator', 'Remove-DMIscsiInitiatorFromHost', 'Remove-DMIscsiInitiator',
                'New-DMNvmeInitiator', 'Remove-DMNvmeInitiator'
            ) -Status 'NotConfigured' -Reason 'Set Initiators.Enabled = $true and supply unused initiator identities to run these lifecycles.'
        }
}
