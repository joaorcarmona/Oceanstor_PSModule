function Write-ValidationProgress {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Category,
        [string]$Status,
        [Nullable[double]]$DurationMs
    )

    if (-not $NoProgress) {
        $progressStatus = if ($Status) {
            "Completed $($checks.Count) checks; last: [$Status] $Name"
        }
        else {
            "Completed $($checks.Count) checks; running [$Category] $Name"
        }
        Write-Progress -Id 1 -Activity "Validating OceanStor $Hostname" -Status $progressStatus -CurrentOperation "[$Category] $Name"
    }

    if ($ShowTestExecution -and $Status) {
        $durationText = if ($null -ne $DurationMs) { " ($DurationMs ms)" } else { '' }
        Write-Host ("[{0}] {1}: {2}{3}" -f $Category, $Name, $Status, $durationText)
    }
}

function Add-ValidationResult {
    param(
        [string]$Name,
        [Alias('Action')]
        [scriptblock]$ValidationAction,
        [string]$ExpectedType,
        [string]$Category = 'Read'
    )

    Write-ValidationProgress -Name $Name -Category $Category
    $startedAt = Get-Date
    try {
        $rows = @(& $ValidationAction)
        $types = @($rows | ForEach-Object { $_.GetType().Name } | Sort-Object -Unique)
        $unexpected = if ($ExpectedType) { @($types | Where-Object { $_ -ne $ExpectedType }) } else { @() }
        $status = if ($rows.Count -eq 0) { 'NoData' } elseif ($unexpected.Count -gt 0) { 'UnexpectedType' } else { 'Passed' }
        $durationMs = [math]::Round(((Get-Date) - $startedAt).TotalMilliseconds, 2)

        $checks.Add([pscustomobject]@{
            Name         = $Name
            Category     = $Category
            Status       = $status
            DurationMs   = $durationMs
            Count        = $rows.Count
            ExpectedType = $ExpectedType
            ActualTypes  = $types
            Error        = $null
        })
        Write-ValidationProgress -Name $Name -Category $Category -Status $status -DurationMs $durationMs

        return $rows
    }
    catch {
        $durationMs = [math]::Round(((Get-Date) - $startedAt).TotalMilliseconds, 2)
        $checks.Add([pscustomobject]@{
            Name         = $Name
            Category     = $Category
            Status       = 'Failed'
            DurationMs   = $durationMs
            Count        = 0
            ExpectedType = $ExpectedType
            ActualTypes  = @()
            Error        = $_.Exception.Message
        })
        Write-ValidationProgress -Name $Name -Category $Category -Status 'Failed' -DurationMs $durationMs

        return @()
    }
}

function Add-SkippedResult {
    param(
        [string[]]$Name,
        [string]$Reason,
        [string]$Status = 'SkippedUnsafe'
    )

    foreach ($commandName in $Name) {
        $checks.Add([pscustomobject]@{
            Name         = $commandName
            Category     = 'Mutation'
            Status       = $Status
            DurationMs   = $null
            Count        = 0
            ExpectedType = $null
            ActualTypes  = @()
            Error        = $Reason
        })
    }
}

function Invoke-MutationStep {
    param(
        [string]$Name,
        [Alias('Action')]
        [scriptblock]$MutationAction,
        [string]$ExpectedType
    )

    $stepName = $Name
    return Add-ValidationResult -Name $Name -Action {
        Set-DMValidationRequestTraceContext -Name $stepName -Category 'Mutation'
        try {
            $result = @(& $MutationAction)
            foreach ($item in $result) {
                if ($item.PSObject.Properties['Code'] -and $item.Code -ne 0) {
                    $detail = if ($item.PSObject.Properties['Description']) { ": $($item.Description)" } else { '' }
                    throw "$stepName returned REST error code $($item.Code)$detail"
                }
            }
            return $result
        }
        finally {
            Set-DMValidationRequestTraceContext
        }
    } -ExpectedType $ExpectedType -Category 'Mutation'
}

function Add-MutationReadVerification {
    param(
        [string]$Name,
        [Alias('Action')]
        [scriptblock]$ValidationAction,
        [string]$ExpectedType
    )

    $verificationName = $Name
    $readAction = $ValidationAction
    return Add-ValidationResult -Name "Verify:$Name" -Action {
        Set-DMValidationRequestTraceContext -Name "Verify:$verificationName" -Category 'MutationRead'
        try {
            $rows = @(& $readAction)
            if ($rows.Count -eq 0) {
                throw "$verificationName did not return the test-owned object or association created by this run."
            }
            return $rows
        }
        finally {
            Set-DMValidationRequestTraceContext
        }
    } -ExpectedType $ExpectedType -Category 'MutationRead'
}

function Register-TestOwnedResource {
    param(
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Identity
    )
    [void]$owned[$Kind].Add($Identity)
}

function Assert-TestOwnedResource {
    param(
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Identity
    )
    if (-not $owned[$Kind].Contains($Identity)) {
        throw "Safety guard refused to modify or remove $Kind '$Identity' because it was not created by this validation run."
    }
}

function Complete-TestOwnedResource {
    param(
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Identity
    )
    [void]$owned[$Kind].Remove($Identity)
}

function Update-TestOwnedResourceIdentity {
    param(
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$OldIdentity,
        [Parameter(Mandatory)][string]$NewIdentity
    )

    Assert-TestOwnedResource -Kind $Kind -Identity $OldIdentity
    if ($owned[$Kind].Contains($NewIdentity)) {
        throw "Cannot rename test-owned $Kind '$OldIdentity' to '$NewIdentity' because the new identity is already registered."
    }
    Complete-TestOwnedResource -Kind $Kind -Identity $OldIdentity
    Register-TestOwnedResource -Kind $Kind -Identity $NewIdentity
}

function Register-CleanupAction {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]
        [Alias('Action')]
        [scriptblock]$CleanupAction
    )

    $cleanupActions.Add([pscustomobject]@{
        Name   = $Name
        Action = $CleanupAction
    })
}

function Invoke-RegisteredCleanup {
    for ($index = $cleanupActions.Count - 1; $index -ge 0; $index--) {
        & $cleanupActions[$index].Action
    }
}

function New-TestName {
    param([Parameter(Mandatory)][string]$Suffix)
    return "$($configuration.NamePrefix)_${runId}_$Suffix"
}

function Test-MutatingConfiguration {
    if (-not $configuration.NamePrefix -or $configuration.NamePrefix -notmatch '^[A-Za-z0-9_.-]+$') {
        throw 'NamePrefix must contain only letters, numbers, underscores, periods, or hyphens.'
    }
    if (($configuration.Lun.Enabled -or $configuration.Nas.Enabled) -and -not $configuration.StoragePoolId) {
        throw 'StoragePoolId is required when Lun.Enabled or Nas.Enabled is true.'
    }
    if ($configuration.Nas.Enabled -and $configuration.Nas.EnableNfs -and -not $configuration.Nas.NfsClientName) {
        throw 'Nas.NfsClientName is required when NAS NFS validation is enabled.'
    }
    if ($configuration.LunGroup.Enabled -and -not $configuration.Lun.Enabled) {
        throw 'Lun.Enabled must be true when LunGroup.Enabled is true so membership tests use a test-owned LUN.'
    }
    if ($configuration.Protection.Enabled -and (-not $configuration.Lun.Enabled -or -not $configuration.LunGroup.Enabled)) {
        throw 'Lun.Enabled and LunGroup.Enabled must be true when Protection.Enabled is true so protection tests use only test-owned storage.'
    }
}

function Wait-DMSnapshotConsistencyGroupReadyForRemoval {
    param(
        [Parameter(Mandatory)][string]$Name,
        [int]$TimeoutSeconds = 300
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $group = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $Name)[0]
        if (-not $group -or $group.'Running Status' -ne 'Rolling Back') {
            return
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for snapshot consistency group '$Name' to finish rolling back before cleanup."
}

function Invoke-OwnedRemoval {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)]
        [Alias('Action')]
        [scriptblock]$RemovalAction
    )

    if (-not $owned[$Kind].Contains($Identity)) {
        return
    }

    $result = @(Invoke-MutationStep -Name $Name -Action {
        Assert-TestOwnedResource -Kind $Kind -Identity $Identity
        & $RemovalAction
    })
    if ($result.Count -gt 0) {
        Complete-TestOwnedResource -Kind $Kind -Identity $Identity
    }
}
