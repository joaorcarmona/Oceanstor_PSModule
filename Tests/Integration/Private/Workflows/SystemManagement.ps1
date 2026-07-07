# Config-gated system-management mutation workflow (Phase 04). Safety contract
# (see docs/system-management/safety-and-live-validation.md):
#   - every sub-workflow is individually gated in IntegrityValidationConfig.psd1 and
#     disabled by default; -RunMutatingTests alone never executes any of them
#   - only test-owned objects are created (run-unique names / dedicated config addresses)
#   - object IDs are captured immediately after create, cleanup is registered immediately,
#     and removal happens by captured ID or the exact recorded address only
#   - pre-existing SNMP, syslog, user, or role configuration is never modified, matched
#     by name pattern, or "cleaned"; a name/address collision aborts the step loudly
#   - cleanup runs through Invoke-RegisteredCleanup (LIFO), which the runner drives from
#     its finally-equivalent path; anything left behind is listed in
#     RemainingTestOwnedResources in the validation report

# Commands each SystemManagement sub-gate exercises. MutationValidation.ps1 and the
# gate-off branches below use this map so disabled gates report cleanly instead of
# falling through to the coverage fallback.
$script:SystemManagementWorkflowCommandGates = [ordered]@{
    AllowSnmpTrapServer     = @('New-DMSnmpTrapServer', 'Set-DMSnmpTrapServer', 'Test-DMSnmpTrapServer', 'Remove-DMSnmpTrapServer')
    AllowSnmpUsmUser        = @('New-DMSnmpUsmUser', 'Set-DMSnmpUsmUser', 'Remove-DMSnmpUsmUser')
    AllowSyslogServer       = @('Add-DMSyslogServer', 'Remove-DMSyslogServer')
    AllowLocalUserLifecycle = @('New-DMRole', 'Set-DMRole', 'New-DMLocalUser', 'Set-DMLocalUser', 'Remove-DMLocalUser', 'Remove-DMRole')
}

function New-SystemManagementTestPassword {
    # Throwaway password for test-owned SNMP USM / local user objects, generated per
    # run and never persisted or reported. The mutation request trace redacts
    # password/passwd fields, so the value never reaches the trace log either.
    $upper = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = [char[]]'abcdefghjkmnpqrstuvwxyz'
    $digit = [char[]]'23456789'
    $special = [char[]]'@#_-'
    $all = $upper + $lower + $digit + $special
    $chars = @(
        ($upper | Get-Random)
        ($lower | Get-Random)
        ($digit | Get-Random)
        ($special | Get-Random)
    ) + @(1..12 | ForEach-Object { $all | Get-Random })
    return -join ($chars | Sort-Object { Get-Random })
}

function ConvertTo-SyslogAddressList {
    # Get-DMSyslogNotification exposes 'Server Addresses' either as an array or as a
    # single comma-joined string depending on the array firmware; normalize both.
    param([AllowNull()][object]$Addresses)
    return @(@($Addresses) | Where-Object { $null -ne $_ } | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

$script:SystemManagementMutationWorkflow = {
    $systemManagement = $configuration.SystemManagement
    $systemManagementEnabled = [bool]($systemManagement -and $systemManagement.Enabled)

    # ---- SNMP trap server lifecycle: create -> update -> test -> remove (by captured ID) ----
    if ($systemManagementEnabled -and $systemManagement.AllowSnmpTrapServer) {
        $trapServerAddress = [string]$systemManagement.SnmpTrapServerAddress
        $trapServerPort = [uint32]$systemManagement.SnmpTrapServerPort
        $trapServerUpdatedPort = $trapServerPort + 1
        $trapServerId = $null
        $trapCreated = @(Invoke-MutationStep -Name 'New-DMSnmpTrapServer' -Action {
            if (@(Get-DMSnmpTrapServer -WebSession $session | Where-Object Address -EQ $trapServerAddress).Count -gt 0) {
                throw "An SNMP trap server with address '$trapServerAddress' already exists; refusing to claim it test-owned. Configure an unused SystemManagement.SnmpTrapServerAddress."
            }
            New-DMSnmpTrapServer -WebSession $session -Address $trapServerAddress -Port $trapServerPort -Confirm:$false
        })
        if ($trapCreated.Count -gt 0) {
            $createdTrapServer = @(Add-MutationReadVerification -Name 'New-DMSnmpTrapServer:ReadBack' -ExpectedType 'OceanStorSnmpTrapServer' -Action {
                @(Get-DMSnmpTrapServer -WebSession $session | Where-Object Address -EQ $trapServerAddress)
            })
            if ($createdTrapServer.Count -gt 0 -and $createdTrapServer[0].Id) {
                $trapServerId = [string]$createdTrapServer[0].Id
                Register-TestOwnedResource -Kind SnmpTrapServer -Identity $trapServerId
                Register-CleanupAction -Name 'Remove-DMSnmpTrapServer' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMSnmpTrapServer' -Kind SnmpTrapServer -Identity $trapServerId -Action {
                        Remove-DMSnmpTrapServer -WebSession $session -Id $trapServerId -Confirm:$false
                    }
                }
                Invoke-MutationStep -Name 'Set-DMSnmpTrapServer' -Action {
                    Assert-TestOwnedResource -Kind SnmpTrapServer -Identity $trapServerId
                    Set-DMSnmpTrapServer -WebSession $session -Id $trapServerId -Port $trapServerUpdatedPort -Confirm:$false
                } | Out-Null
                Add-MutationReadVerification -Name 'Set-DMSnmpTrapServer:ReadBack' -ExpectedType 'OceanStorSnmpTrapServer' -Action {
                    $updated = @(Get-DMSnmpTrapServer -WebSession $session -Id $trapServerId)
                    if ($updated.Count -eq 0 -or $updated[0].Port -ne "$trapServerUpdatedPort") {
                        throw "Set-DMSnmpTrapServer port mismatch: expected '$trapServerUpdatedPort', found '$($updated[0].Port)'."
                    }
                    $updated
                } | Out-Null
                Invoke-MutationStep -Name 'Test-DMSnmpTrapServer' -Action {
                    # Sends a single test trap to the test-owned address only; changes no array state.
                    Assert-TestOwnedResource -Kind SnmpTrapServer -Identity $trapServerId
                    Test-DMSnmpTrapServer -WebSession $session -Address $trapServerAddress -Port $trapServerUpdatedPort
                } | Out-Null
            }
            else {
                # No safe removal target exists without a captured ID; register the
                # address so the leftover is reported in RemainingTestOwnedResources.
                Register-TestOwnedResource -Kind SnmpTrapServer -Identity $trapServerAddress
                Add-SkippedResult -Name @('Set-DMSnmpTrapServer', 'Test-DMSnmpTrapServer', 'Remove-DMSnmpTrapServer') -Status 'Blocked' `
                    -Reason "The created SNMP trap server '$trapServerAddress' could not be read back with an ID; remove it manually with Get-DMSnmpTrapServer / Remove-DMSnmpTrapServer -Id <id>."
            }
        }
        else {
            Add-SkippedResult -Name @('Set-DMSnmpTrapServer', 'Test-DMSnmpTrapServer', 'Remove-DMSnmpTrapServer') -Status 'Blocked' `
                -Reason 'New-DMSnmpTrapServer did not succeed, so the dependent trap server steps were skipped; nothing was created or left behind.'
        }
    }
    else {
        Add-SkippedResult -Name $script:SystemManagementWorkflowCommandGates.AllowSnmpTrapServer -Status 'NotConfigured' `
            -Reason 'Set SystemManagement.Enabled = $true and SystemManagement.AllowSnmpTrapServer = $true to run the test-owned SNMP trap server lifecycle.'
    }

    # ---- SNMP USM user lifecycle: create -> update -> remove (name is the REST ID) ----
    if ($systemManagementEnabled -and $systemManagement.AllowSnmpUsmUser) {
        $snmpUsmUserName = New-TestName -Suffix 'usm'
        $usmCreated = @(Invoke-MutationStep -Name 'New-DMSnmpUsmUser' -Action {
            if (@(Get-DMSnmpUsmUser -WebSession $session | Where-Object Name -EQ $snmpUsmUserName).Count -gt 0) {
                throw "An SNMP USM user named '$snmpUsmUserName' already exists; refusing to claim it test-owned."
            }
            $authPassword = ConvertTo-SecureString (New-SystemManagementTestPassword) -AsPlainText -Force
            $privacyPassword = ConvertTo-SecureString (New-SystemManagementTestPassword) -AsPlainText -Force
            New-DMSnmpUsmUser -WebSession $session -Name $snmpUsmUserName `
                -AuthProtocol $systemManagement.SnmpUsmAuthProtocol -AuthPassword $authPassword `
                -PrivacyProtocol $systemManagement.SnmpUsmPrivacyProtocol -PrivacyPassword $privacyPassword `
                -UserLevel 0 -Confirm:$false
        })
        if ($usmCreated.Count -gt 0) {
            Register-TestOwnedResource -Kind SnmpUsmUser -Identity $snmpUsmUserName
            Register-CleanupAction -Name 'Remove-DMSnmpUsmUser' -Action {
                Invoke-OwnedRemoval -Name 'Remove-DMSnmpUsmUser' -Kind SnmpUsmUser -Identity $snmpUsmUserName -Action {
                    Remove-DMSnmpUsmUser -WebSession $session -Id $snmpUsmUserName -Confirm:$false
                }
            }
            Add-MutationReadVerification -Name 'New-DMSnmpUsmUser:ReadBack' -ExpectedType 'OceanStorSnmpUsmUser' -Action {
                @(Get-DMSnmpUsmUser -WebSession $session | Where-Object Name -EQ $snmpUsmUserName)
            } | Out-Null
            Invoke-MutationStep -Name 'Set-DMSnmpUsmUser' -Action {
                Assert-TestOwnedResource -Kind SnmpUsmUser -Identity $snmpUsmUserName
                Set-DMSnmpUsmUser -WebSession $session -Name $snmpUsmUserName -UserLevel 1 -Confirm:$false
            } | Out-Null
            Add-MutationReadVerification -Name 'Set-DMSnmpUsmUser:ReadBack' -ExpectedType 'OceanStorSnmpUsmUser' -Action {
                $updated = @(Get-DMSnmpUsmUser -WebSession $session | Where-Object Name -EQ $snmpUsmUserName)
                if ($updated.Count -eq 0 -or $updated[0].'User Level' -ne '1') {
                    throw "Set-DMSnmpUsmUser user level mismatch: expected '1' (read-only), found '$($updated[0].'User Level')'."
                }
                $updated
            } | Out-Null
        }
        else {
            # A rejection here is an accepted, non-fatal outcome: array security policy
            # (password complexity, USM user limits) may refuse the generated user.
            # The create step above carries the array's message; nothing was created.
            Add-SkippedResult -Name @('Set-DMSnmpUsmUser', 'Remove-DMSnmpUsmUser') -Status 'Blocked' `
                -Reason 'New-DMSnmpUsmUser did not succeed (the array security policy may have rejected the generated test user); dependent steps were skipped and nothing was left behind.'
        }
    }
    else {
        Add-SkippedResult -Name $script:SystemManagementWorkflowCommandGates.AllowSnmpUsmUser -Status 'NotConfigured' `
            -Reason 'Set SystemManagement.Enabled = $true and SystemManagement.AllowSnmpUsmUser = $true to run the test-owned SNMP USM user lifecycle.'
    }

    # ---- Syslog server lifecycle: add -> remove by the exact recorded address ----
    if ($systemManagementEnabled -and $systemManagement.AllowSyslogServer) {
        $syslogServerAddress = [string]$systemManagement.SyslogServerAddress
        $syslogAdded = @(Invoke-MutationStep -Name 'Add-DMSyslogServer' -Action {
            $existing = ConvertTo-SyslogAddressList -Addresses (Get-DMSyslogNotification -WebSession $session).'Server Addresses'
            if ($existing -contains $syslogServerAddress) {
                throw "A syslog server with address '$syslogServerAddress' already exists; refusing to claim it test-owned. Configure an unused SystemManagement.SyslogServerAddress."
            }
            Add-DMSyslogServer -WebSession $session -Address $syslogServerAddress -Confirm:$false
        })
        if ($syslogAdded.Count -gt 0) {
            Register-TestOwnedResource -Kind SyslogServer -Identity $syslogServerAddress
            Register-CleanupAction -Name 'Remove-DMSyslogServer' -Action {
                Invoke-OwnedRemoval -Name 'Remove-DMSyslogServer' -Kind SyslogServer -Identity $syslogServerAddress -Action {
                    # Removes only the exact address recorded above — never a pattern.
                    Remove-DMSyslogServer -WebSession $session -Address $syslogServerAddress -Confirm:$false
                }
            }
            Add-MutationReadVerification -Name 'Add-DMSyslogServer:ReadBack' -ExpectedType 'OceanStorSyslogNotification' -Action {
                $notification = Get-DMSyslogNotification -WebSession $session
                $addresses = ConvertTo-SyslogAddressList -Addresses $notification.'Server Addresses'
                if ($addresses -notcontains $syslogServerAddress) {
                    throw "Add-DMSyslogServer read-back did not find the test-owned address '$syslogServerAddress'."
                }
                $notification
            } | Out-Null
        }
        else {
            Add-SkippedResult -Name @('Remove-DMSyslogServer') -Status 'Blocked' `
                -Reason 'Add-DMSyslogServer did not succeed, so no removal was attempted; nothing was created or left behind.'
        }
    }
    else {
        Add-SkippedResult -Name $script:SystemManagementWorkflowCommandGates.AllowSyslogServer -Status 'NotConfigured' `
            -Reason 'Set SystemManagement.Enabled = $true and SystemManagement.AllowSyslogServer = $true to run the test-owned syslog server add/remove lifecycle.'
    }

    # ---- Local role + local user lifecycle (SECURITY-SENSITIVE, default off) ----
    # Creates one test-owned role and one test-owned local user assigned to it, updates
    # both, then cleanup removes the user before the role (LIFO registration order).
    if ($systemManagementEnabled -and $systemManagement.AllowLocalUserLifecycle) {
        $localRoleName = New-TestName -Suffix 'rol'
        $localUserName = New-TestName -Suffix 'usr'
        $localRoleId = $null
        $localUserId = $null
        $roleCreated = @(Invoke-MutationStep -Name 'New-DMRole' -Action {
            if (@(Get-DMRole -WebSession $session | Where-Object Name -EQ $localRoleName).Count -gt 0) {
                throw "A role named '$localRoleName' already exists; refusing to claim it test-owned."
            }
            New-DMRole -WebSession $session -Name $localRoleName -Description "Integrity run $runId" `
                -RoleOwnerGroup $systemManagement.LocalRoleOwnerGroup -RoleSource $systemManagement.LocalRoleSource -Confirm:$false
        })
        if ($roleCreated.Count -gt 0) {
            $createdRole = @(Add-MutationReadVerification -Name 'New-DMRole:ReadBack' -ExpectedType 'OceanStorRole' -Action {
                @(Get-DMRole -WebSession $session | Where-Object Name -EQ $localRoleName)
            })
            if ($createdRole.Count -gt 0 -and $createdRole[0].Id) {
                $localRoleId = [string]$createdRole[0].Id
                Register-TestOwnedResource -Kind Role -Identity $localRoleId
                Register-CleanupAction -Name 'Remove-DMRole' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMRole' -Kind Role -Identity $localRoleId -Action {
                        Remove-DMRole -WebSession $session -Id $localRoleId -Confirm:$false
                    }
                }
                Invoke-MutationStep -Name 'Set-DMRole' -Action {
                    Assert-TestOwnedResource -Kind Role -Identity $localRoleId
                    Set-DMRole -WebSession $session -Id $localRoleId -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null

                $userCreated = @(Invoke-MutationStep -Name 'New-DMLocalUser' -Action {
                    if (@(Get-DMLocalUser -WebSession $session | Where-Object Name -EQ $localUserName).Count -gt 0) {
                        throw "A local user named '$localUserName' already exists; refusing to claim it test-owned."
                    }
                    $userPassword = ConvertTo-SecureString (New-SystemManagementTestPassword) -AsPlainText -Force
                    New-DMLocalUser -WebSession $session -Name $localUserName -Password $userPassword `
                        -RoleId $localRoleId -Description "Integrity run $runId" -Confirm:$false
                })
                if ($userCreated.Count -gt 0) {
                    $createdUser = @(Add-MutationReadVerification -Name 'New-DMLocalUser:ReadBack' -ExpectedType 'OceanStorLocalUser' -Action {
                        @(Get-DMLocalUser -WebSession $session | Where-Object Name -EQ $localUserName)
                    })
                    # The user resource is name-addressed on most firmware; fall back to
                    # the exact test-owned name when no separate ID is returned.
                    $localUserId = if ($createdUser.Count -gt 0 -and $createdUser[0].Id) { [string]$createdUser[0].Id } else { $localUserName }
                    Register-TestOwnedResource -Kind LocalUser -Identity $localUserId
                    # Registered after the role cleanup so LIFO removes the user first.
                    Register-CleanupAction -Name 'Remove-DMLocalUser' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMLocalUser' -Kind LocalUser -Identity $localUserId -Action {
                            Remove-DMLocalUser -WebSession $session -Id $localUserId -Confirm:$false
                        }
                    }
                    Invoke-MutationStep -Name 'Set-DMLocalUser' -Action {
                        Assert-TestOwnedResource -Kind LocalUser -Identity $localUserId
                        Set-DMLocalUser -WebSession $session -Id $localUserId -Description "Integrity validation updated $runId" -Confirm:$false
                    } | Out-Null
                    Add-MutationReadVerification -Name 'Set-DMLocalUser:ReadBack' -ExpectedType 'OceanStorLocalUser' -Action {
                        $updated = @(Get-DMLocalUser -WebSession $session | Where-Object Name -EQ $localUserName)
                        if ($updated.Count -eq 0 -or $updated[0].Description -ne "Integrity validation updated $runId") {
                            throw "Set-DMLocalUser description mismatch: expected 'Integrity validation updated $runId', found '$($updated[0].Description)'."
                        }
                        $updated
                    } | Out-Null
                }
                else {
                    # Accepted, non-fatal outcome: array security policy may refuse the
                    # generated user (password policy, user count limits).
                    Add-SkippedResult -Name @('Set-DMLocalUser', 'Remove-DMLocalUser') -Status 'Blocked' `
                        -Reason 'New-DMLocalUser did not succeed (the array security policy may have rejected the generated test user); dependent steps were skipped and nothing was left behind. The test-owned role is still removed by cleanup.'
                }
            }
            else {
                # No safe removal target exists without a captured ID; register the
                # name so the leftover is reported in RemainingTestOwnedResources.
                Register-TestOwnedResource -Kind Role -Identity $localRoleName
                Add-SkippedResult -Name @('Set-DMRole', 'New-DMLocalUser', 'Set-DMLocalUser', 'Remove-DMLocalUser', 'Remove-DMRole') -Status 'Blocked' `
                    -Reason "The created role '$localRoleName' could not be read back with an ID; remove it manually with Get-DMRole / Remove-DMRole -Id <id>."
            }
        }
        else {
            Add-SkippedResult -Name @('Set-DMRole', 'New-DMLocalUser', 'Set-DMLocalUser', 'Remove-DMLocalUser', 'Remove-DMRole') -Status 'Blocked' `
                -Reason 'New-DMRole did not succeed, so the dependent role/user steps were skipped; nothing was created or left behind.'
        }
    }
    else {
        Add-SkippedResult -Name $script:SystemManagementWorkflowCommandGates.AllowLocalUserLifecycle -Status 'NotConfigured' `
            -Reason 'SECURITY-SENSITIVE: set SystemManagement.Enabled = $true and SystemManagement.AllowLocalUserLifecycle = $true (explicit reviewed decision) to run the test-owned local role/user lifecycle.'
    }
}
