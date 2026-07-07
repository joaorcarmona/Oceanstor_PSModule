# Config-gated failover-group mutation workflow (Phase 06). Safety contract
# (see docs/network/safety-and-live-validation.md):
#   - gated behind Network.Enabled AND Network.AllowFailoverGroupLifecycle in
#     IntegrityValidationConfig.psd1, both disabled by default; -RunMutatingTests
#     alone never executes this workflow
#   - only a test-owned, run-unique customized failover group is created; its ID
#     is captured from an immediate read-back and cleanup is registered before
#     any further step runs; removal happens by that captured ID only
#   - pre-existing failover groups, LIFs, VLANs, bonds, ports, routes, and
#     management addressing are never touched; a name collision aborts loudly
#   - member add/remove is intentionally skipped: per the Dorado 6.1.6 REST
#     reference, failover-group members are Ethernet ports (213), bond ports
#     (235) or VLANs (280) -- not LIFs -- and the harness never claims a live
#     port or creates a VLAN on one without the idle-port guard documented in
#     docs/network/safety-and-live-validation.md. The member step runs only once
#     a test-owned eligible member exists (future VLAN workflow).
#   - cleanup runs through Invoke-RegisteredCleanup (LIFO); anything left behind
#     is listed in RemainingTestOwnedResources in the validation report

# Commands the Network.AllowFailoverGroupLifecycle gate exercises. The gate-off
# branch below uses this map so disabled gates report cleanly instead of falling
# through to the coverage fallback.
$script:FailoverGroupWorkflowCommandGates = [ordered]@{
    AllowFailoverGroupLifecycle = @(
        'New-DMFailoverGroup', 'Set-DMFailoverGroup',
        'Add-DMFailoverGroupMember', 'Remove-DMFailoverGroupMember',
        'Remove-DMFailoverGroup'
    )
}

$script:FailoverGroupMutationWorkflow = {
    $network = $configuration.Network
    $networkEnabled = [bool]($network -and $network.Enabled)

    # ---- Failover group lifecycle: create -> modify -> (member skip) -> remove by captured ID ----
    if ($networkEnabled -and $network.AllowFailoverGroupLifecycle) {
        $failoverGroupName = New-TestName -Suffix 'fg'
        $failoverGroupId = $null
        $failoverGroupCreated = @(Invoke-MutationStep -Name 'New-DMFailoverGroup' -Action {
            if (@(Get-DMFailoverGroup -WebSession $session -Name $failoverGroupName).Count -gt 0) {
                throw "A failover group named '$failoverGroupName' already exists; refusing to claim it test-owned."
            }
            New-DMFailoverGroup -WebSession $session -Name $failoverGroupName `
                -Description "Integrity run $runId" -FailoverGroupServiceType 0 -Confirm:$false
        })
        if ($failoverGroupCreated.Count -gt 0) {
            $createdFailoverGroup = @(Add-MutationReadVerification -Name 'New-DMFailoverGroup:ReadBack' -ExpectedType 'OceanStorFailoverGroup' -Action {
                @(Get-DMFailoverGroup -WebSession $session -Name $failoverGroupName)
            })
            if ($createdFailoverGroup.Count -gt 0 -and $createdFailoverGroup[0].Id) {
                $failoverGroupId = [string]$createdFailoverGroup[0].Id
                Register-TestOwnedResource -Kind FailoverGroup -Identity $failoverGroupId
                Register-CleanupAction -Name 'Remove-DMFailoverGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMFailoverGroup' -Kind FailoverGroup -Identity $failoverGroupId -Action {
                        Remove-DMFailoverGroup -WebSession $session -Id $failoverGroupId -Confirm:$false
                    }
                }
                Invoke-MutationStep -Name 'Set-DMFailoverGroup' -Action {
                    Assert-TestOwnedResource -Kind FailoverGroup -Identity $failoverGroupId
                    Set-DMFailoverGroup -WebSession $session -Id $failoverGroupId -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMFailoverGroup:ReadBack' -ExpectedType 'OceanStorFailoverGroup' -Action {
                    $updated = @(Get-DMFailoverGroup -WebSession $session -Id $failoverGroupId)
                    if ($updated.Count -eq 0 -or $updated[0].Description -ne "Integrity validation updated $runId") {
                        throw "Set-DMFailoverGroup description mismatch: expected 'Integrity validation updated $runId', found '$($updated[0].Description)'."
                    }
                    $updated
                } | Out-Null
                Invoke-MutationStep -Name 'Get-DMFailoverGroupMember:Workflow' -Action {
                    # Read-only round trip of the member getter against the freshly
                    # created, test-owned group -- it must report zero members.
                    $members = @(Get-DMFailoverGroupMember -WebSession $session -Id $failoverGroupId)
                    if ($members.Count -ne 0) {
                        throw "The test-owned failover group '$failoverGroupId' unexpectedly reports $($members.Count) member(s); refusing to continue."
                    }
                    [pscustomobject]@{ FailoverGroupId = $failoverGroupId; MemberCount = 0 }
                } | Out-Null
                # Member add/remove is skipped by design until a test-owned eligible
                # member type exists. REST members are ports/bonds/VLANs; the harness
                # never claims a pre-existing port and never creates a VLAN on a port
                # without the idle-port guard, so there is nothing safe to attach yet.
                Add-SkippedResult -Name @('Add-DMFailoverGroupMember', 'Remove-DMFailoverGroupMember') -Status 'SkippedUnsafe' `
                    -Reason 'Failover-group members are Ethernet ports, bond ports or VLANs (REST ASSOCIATEOBJTYPE 213/235/280). The workflow owns no such member object and never claims live ports; member add/remove stays skipped until a test-owned VLAN workflow with an idle-port guard exists.'
            }
            else {
                # No safe removal target exists without a captured ID; register the
                # name so the leftover is reported in RemainingTestOwnedResources.
                Register-TestOwnedResource -Kind FailoverGroup -Identity $failoverGroupName
                Add-SkippedResult -Name @('Set-DMFailoverGroup', 'Add-DMFailoverGroupMember', 'Remove-DMFailoverGroupMember', 'Remove-DMFailoverGroup') -Status 'Blocked' `
                    -Reason "The created failover group '$failoverGroupName' could not be read back with an ID; remove it manually with Get-DMFailoverGroup / Remove-DMFailoverGroup -Id <id>."
            }
        }
        else {
            Add-SkippedResult -Name @('Set-DMFailoverGroup', 'Add-DMFailoverGroupMember', 'Remove-DMFailoverGroupMember', 'Remove-DMFailoverGroup') -Status 'Blocked' `
                -Reason 'New-DMFailoverGroup did not succeed, so the dependent failover-group steps were skipped; nothing was created or left behind.'
        }
    }
    else {
        Add-SkippedResult -Name $script:FailoverGroupWorkflowCommandGates.AllowFailoverGroupLifecycle -Status 'NotConfigured' `
            -Reason 'Set Network.Enabled = $true and Network.AllowFailoverGroupLifecycle = $true to run the test-owned failover-group lifecycle.'
    }
}
