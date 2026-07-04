$script:QuotaMutationWorkflow = {
    if ($owned.FileSystem.Contains($fileSystemName) -and $owned.DTree.Contains($dTreeName) -and $configuration.Nas.EnableQuota) {
        $quota = @(Invoke-MutationStep -Name 'New-DMQuota' -ExpectedType 'OceanstorQuota' -Action {
            Assert-TestOwnedResource -Kind DTree -Identity $dTreeName
            New-DMQuota -WebSession $session -FileSystemName $fileSystemName -DtreeName $dTreeName `
                -SpaceHardLimit "$($configuration.Nas.QuotaSpaceHardLimitGB)GB"
        })
        if ($quota.Count -gt 0 -and $quota[0].Id) {
            $quotaId = $quota[0].Id
            Register-TestOwnedResource -Kind Quota -Identity $quotaId
            Register-CleanupAction -Name 'Remove-DMQuota' -Action {
                Invoke-OwnedRemoval -Name 'Remove-DMQuota' -Kind Quota -Identity $quotaId -Action {
                    Remove-DMQuota -WebSession $session -Id $quotaId -Confirm:$false
                }
            }

            $expandedSpaceHardLimitGB = $configuration.Nas.QuotaSpaceHardLimitGB + 10
            Invoke-MutationStep -Name 'Set-DMQuota' -Action {
                Assert-TestOwnedResource -Kind Quota -Identity $quotaId
                Set-DMQuota -WebSession $session -Id $quotaId -SpaceHardLimit "${expandedSpaceHardLimitGB}GB" -Confirm:$false
            } | Out-Null
            Add-MutationReadVerification -Name 'Set-DMQuota:ReadBack' -ExpectedType 'OceanstorQuota' -Action {
                $updated = @(Get-DMQuota -WebSession $session -Id $quotaId)
                $expectedBytes = ConvertTo-DMQuotaByte -Capacity "${expandedSpaceHardLimitGB}GB"
                if ($updated.Count -gt 0 -and $updated[0].'Space Hard Quota' -ne $expectedBytes) {
                    throw "Set-DMQuota space hard quota mismatch: expected $expectedBytes, got '$($updated[0].'Space Hard Quota')'."
                }
                $updated
            } | Out-Null
        }
    }
    elseif (-not $configuration.Nas.EnableQuota) {
        Add-SkippedResult -Name @('Get-DMQuota', 'New-DMQuota', 'Set-DMQuota', 'Remove-DMQuota') -Status 'NotConfigured' -Reason 'Set Nas.EnableQuota = $true to validate a quota on the test-owned dTree.'
    }
}
