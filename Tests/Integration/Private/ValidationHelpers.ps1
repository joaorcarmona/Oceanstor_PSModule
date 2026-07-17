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

function ConvertTo-ValidationRunLogField {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ([string]$Value -replace '\r?\n', ' ' -replace '\|', '/').Trim()
}

function Write-ValidationRunLog {
    if ([string]::IsNullOrWhiteSpace($script:GetterIntegrityRunLogPath)) {
        return
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('date | main command | arguments | start time | end time |')

    foreach ($entry in $script:GetterIntegrityRunLogEntries) {
        $fields = @(
            $entry.Date
            $entry.MainCommand
            $entry.Arguments
            $entry.StartTime
            $entry.EndTime
        ) | ForEach-Object { ConvertTo-ValidationRunLogField $_ }

        $lines.Add(('{0} | {1} | {2} | {3} | {4} |' -f $fields[0], $fields[1], $fields[2], $fields[3], $fields[4]))
    }

    $lines | Set-Content -LiteralPath $script:GetterIntegrityRunLogPath
}

function Initialize-ValidationRunLog {
    if ([string]::IsNullOrWhiteSpace($script:GetterIntegrityRunLogPath)) {
        return
    }

    $logDirectory = Split-Path -Path $script:GetterIntegrityRunLogPath -Parent
    if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory)) {
        $null = New-Item -Path $logDirectory -ItemType Directory -Force
    }

    if ($null -eq $script:GetterIntegrityRunLogEntries) {
        $script:GetterIntegrityRunLogEntries = [System.Collections.Generic.List[object]]::new()
    }

    Write-ValidationRunLog
}

function Get-ValidationActionCommandLogMetadata {
    param(
        [string]$Name,
        [scriptblock]$ValidationAction
    )

    $command = @($ValidationAction.Ast.FindAll({
        param($node)
        if ($node -isnot [System.Management.Automation.Language.CommandAst]) {
            return $false
        }

        $commandName = $node.GetCommandName()
        return $commandName -and $commandName -notin @(
            'Set-DMValidationRequestTraceContext',
            'Assert-TestOwnedResource',
            'ForEach-Object',
            'Where-Object',
            'Out-Null',
            'return'
        )
    }, $true))[0]

    $mainCommand = if ($command) { $command.GetCommandName() } else { ($Name -replace '^Verify:', '' -split ':')[0] }
    $arguments = if ($command -and $command.CommandElements.Count -gt 1) {
        @($command.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text }) -join ' '
    }
    else {
        $nameParts = @($Name -replace '^Verify:', '' -split ':')
        if ($nameParts.Count -gt 1) { $nameParts[1..($nameParts.Count - 1)] -join ':' } else { '' }
    }

    [pscustomobject]@{
        MainCommand = $mainCommand
        Arguments   = $arguments
    }
}

function Start-ValidationCommandLogEntry {
    param(
        [string]$Name,
        [scriptblock]$ValidationAction,
        [datetime]$StartedAt,
        [string]$MainCommand,
        [string]$Arguments
    )

    if ([string]::IsNullOrWhiteSpace($script:GetterIntegrityRunLogPath)) {
        return $null
    }

    if ($null -eq $script:GetterIntegrityRunLogEntries) {
        $script:GetterIntegrityRunLogEntries = [System.Collections.Generic.List[object]]::new()
    }

    $metadata = if ($MainCommand) {
        [pscustomobject]@{
            MainCommand = $MainCommand
            Arguments   = $Arguments
        }
    }
    else {
        Get-ValidationActionCommandLogMetadata -Name $Name -ValidationAction $ValidationAction
    }
    $entry = [pscustomobject]@{
        Date        = $StartedAt.ToString('yyyy-MM-dd')
        MainCommand = $metadata.MainCommand
        Arguments   = $metadata.Arguments
        StartTime   = $StartedAt.ToString('HH:mm:ss.fff')
        EndTime     = $null
    }

    $script:GetterIntegrityRunLogEntries.Add($entry)
    Write-ValidationRunLog

    return $entry
}

function Complete-ValidationCommandLogEntry {
    param(
        [AllowNull()][object]$Entry,
        [datetime]$EndedAt
    )

    if ($null -eq $Entry -or [string]::IsNullOrWhiteSpace($script:GetterIntegrityRunLogPath)) {
        return
    }

    $Entry.EndTime = $EndedAt.ToString('HH:mm:ss.fff')
    Write-ValidationRunLog
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
    $logEntry = Start-ValidationCommandLogEntry -Name $Name -ValidationAction $ValidationAction -StartedAt $startedAt
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
        Complete-ValidationCommandLogEntry -Entry $logEntry -EndedAt (Get-Date)

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
        Complete-ValidationCommandLogEntry -Entry $logEntry -EndedAt (Get-Date)

        return @()
    }
}

function Add-SkippedResult {
    param(
        [string[]]$Name,
        [string]$Reason,
        [string]$Status = 'SkippedUnsafe',
        [string]$Category = 'Mutation'
    )

    foreach ($commandName in $Name) {
        $checks.Add([pscustomobject]@{
            Name         = $commandName
            Category     = $Category
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
        [string]$ExpectedType,
        # Result category. Defaults to the mutation lane; the supervised
        # network-stack workflow passes 'Supervised' so its rows group separately.
        [string]$Category = 'Mutation'
    )

    $stepName = $Name
    $stepCategory = $Category
    return Add-ValidationResult -Name $Name -Action {
        Set-DMValidationRequestTraceContext -Name $stepName -Category $stepCategory
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
    } -ExpectedType $ExpectedType -Category $stepCategory
}

function Add-MutationReadVerification {
    param(
        [string]$Name,
        [Alias('Action')]
        [scriptblock]$ValidationAction,
        [string]$ExpectedType,
        # Read-verification category. Defaults to the mutation read lane; the
        # supervised network-stack workflow passes 'SupervisedRead'.
        [string]$Category = 'MutationRead'
    )

    $verificationName = $Name
    $readAction = $ValidationAction
    $readCategory = $Category
    return Add-ValidationResult -Name "Verify:$Name" -Action {
        Set-DMValidationRequestTraceContext -Name "Verify:$verificationName" -Category $readCategory
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
    } -ExpectedType $ExpectedType -Category $readCategory
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
        [scriptblock]$CleanupAction,
        [object[]]$ArgumentList = @()
    )

    $cleanupActions.Add([pscustomobject]@{
        Name      = $Name
        Action    = $CleanupAction
        Arguments = $ArgumentList
    })
}

function Invoke-RegisteredCleanup {
    for ($index = $cleanupActions.Count - 1; $index -ge 0; $index--) {
        $arguments = @($cleanupActions[$index].Arguments)
        & $cleanupActions[$index].Action @arguments
    }
}

function New-TestName {
    param([Parameter(Mandatory)][string]$Suffix)
    return "$($configuration.NamePrefix)_${runId}_$Suffix"
}

function New-ReportTaskName {
    # The pms/report_task API caps names at 31 characters on live arrays (the
    # documented 32 is off by one: longer names are accepted in the request but
    # the task is never created), so unlike New-TestName this omits the run
    # timestamp; the per-run token embedded in the suffix keeps names unique.
    param([Parameter(Mandatory)][string]$Suffix)
    $name = "$($configuration.NamePrefix)_$Suffix"
    if ($name.Length -gt 31) {
        throw "Report task name '$name' exceeds the 31-character pms/report_task live API limit."
    }
    return $name
}

function Test-MutatingConfiguration {
    if (-not $configuration.NamePrefix -or $configuration.NamePrefix -notmatch '^[A-Za-z0-9_.-]+$') {
        throw 'NamePrefix must contain only letters, numbers, underscores, periods, or hyphens.'
    }
    if ($configuration.StoragePool -and $configuration.StoragePool.Enabled -and -not $configuration.StoragePool.PoolName) {
        throw 'StoragePool.PoolName is required when StoragePool.Enabled is true; supply the exact name of a pre-existing pool you accept being renamed and restored.'
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
    if ($configuration.QoS.Enabled -and (-not $configuration.Lun.Enabled -or -not $configuration.LunGroup.Enabled)) {
        throw 'Lun.Enabled and LunGroup.Enabled must be true when QoS.Enabled is true so SmartQoS tests use only test-owned storage.'
    }
    if ($configuration.HyperCDPSchedule.Enabled -and -not $configuration.Lun.Enabled) {
        throw 'Lun.Enabled must be true when HyperCDPSchedule.Enabled is true so schedule association tests use a test-owned LUN.'
    }
    if ($configuration.HyperCDPSchedule.Enabled) {
        if ($configuration.HyperCDPSchedule.FrequencyValueSeconds -lt 3 -or $configuration.HyperCDPSchedule.FrequencyValueSeconds -gt 86400) {
            throw 'HyperCDPSchedule.FrequencyValueSeconds must be between 3 and 86400.'
        }
        if ($configuration.HyperCDPSchedule.FrequencySnapshotCount -lt 1) {
            throw 'HyperCDPSchedule.FrequencySnapshotCount must be greater than zero.'
        }
    }
    if ($configuration.Replication.Enabled) {
        if (-not $configuration.Lun.Enabled) {
            throw 'Lun.Enabled must be true when Replication.Enabled is true so the workflow uses a test-owned local LUN.'
        }
        if (-not $configuration.Replication.AllowDrMutation) {
            throw 'Replication.AllowDrMutation must be true to acknowledge remote replication pair and group mutation against a lab DR target.'
        }
        if (-not $configuration.Replication.RemoteDeviceId -and -not $configuration.Replication.RemoteDeviceName) {
            throw 'Replication.RemoteDeviceId or Replication.RemoteDeviceName is required when Replication.Enabled is true.'
        }
        if (-not $configuration.Replication.RemoteLunId -and -not $configuration.Replication.RemoteLunName) {
            throw 'Replication.RemoteLunId or Replication.RemoteLunName is required when Replication.Enabled is true.'
        }
    }
    if ($configuration.SystemManagement -and $configuration.SystemManagement.Enabled) {
        if ($configuration.SystemManagement.AllowSnmpTrapServer) {
            if (-not $configuration.SystemManagement.SnmpTrapServerAddress) {
                throw 'SystemManagement.SnmpTrapServerAddress is required when SystemManagement.AllowSnmpTrapServer is true; supply an unused address you own.'
            }
            if (-not $configuration.SystemManagement.SnmpTrapServerPort) {
                throw 'SystemManagement.SnmpTrapServerPort is required when SystemManagement.AllowSnmpTrapServer is true.'
            }
        }
        if ($configuration.SystemManagement.AllowSnmpUsmUser -and (-not $configuration.SystemManagement.SnmpUsmAuthProtocol -or -not $configuration.SystemManagement.SnmpUsmPrivacyProtocol)) {
            throw 'SystemManagement.SnmpUsmAuthProtocol and SystemManagement.SnmpUsmPrivacyProtocol are required when SystemManagement.AllowSnmpUsmUser is true.'
        }
        if ($configuration.SystemManagement.AllowSyslogServer -and -not $configuration.SystemManagement.SyslogServerAddress) {
            throw 'SystemManagement.SyslogServerAddress is required when SystemManagement.AllowSyslogServer is true; supply an unused address you own.'
        }
        if ($configuration.SystemManagement.AllowLocalUserLifecycle -and (-not $configuration.SystemManagement.LocalRoleOwnerGroup -or -not $configuration.SystemManagement.LocalRoleSource)) {
            throw 'SystemManagement.LocalRoleOwnerGroup and SystemManagement.LocalRoleSource are required when SystemManagement.AllowLocalUserLifecycle is true.'
        }
    }
    if ($configuration.HyperMetro.Enabled) {
        if (-not $configuration.Lun.Enabled) {
            throw 'Lun.Enabled must be true when HyperMetro.Enabled is true so the workflow uses a test-owned local LUN.'
        }
        if (-not $configuration.HyperMetro.AllowDrMutation) {
            throw 'HyperMetro.AllowDrMutation must be true to acknowledge HyperMetro pair and group mutation against a lab DR target.'
        }
        if (-not $configuration.HyperMetro.RemoteDeviceId -and -not $configuration.HyperMetro.RemoteDeviceName) {
            throw 'HyperMetro.RemoteDeviceId or HyperMetro.RemoteDeviceName is required when HyperMetro.Enabled is true.'
        }
        if (-not $configuration.HyperMetro.RemoteLunId -and -not $configuration.HyperMetro.RemoteLunName) {
            throw 'HyperMetro.RemoteLunId or HyperMetro.RemoteLunName is required when HyperMetro.Enabled is true.'
        }
        if (-not $configuration.HyperMetro.DomainId -and -not $configuration.HyperMetro.DomainName) {
            throw 'HyperMetro.DomainId or HyperMetro.DomainName is required when HyperMetro.Enabled is true.'
        }
    }
}

function Test-SupervisedConfiguration {
    # Validates the Network.Supervised block used by the operator-supervised
    # network-stack workflows. Only called when a supervised run is active
    # (-RunSupervisedTests + Network.Enabled + Network.Supervised.Enabled).
    $network = $configuration.Network
    if (-not ($network -and $network.Supervised)) {
        throw 'Network.Supervised configuration block is required when -RunSupervisedTests is used with Network.Enabled.'
    }
    $sup = $network.Supervised
    $netStack = [bool]$sup.AllowNetworkStackLifecycle
    $fgStack = [bool]$sup.AllowFailoverGroupStackLifecycle
    if (-not ($netStack -or $fgStack)) {
        # Master gate on but no stack selected; the workflow reports each stack
        # NotConfigured. Nothing else to validate.
        return
    }
    if (@($sup.PortLocations).Count -lt 2) {
        throw 'Network.Supervised.PortLocations must list at least two link-down front-end port Location values (ideally one per controller).'
    }
    $requiredTags = if ($netStack) { 4 } else { 2 }
    if (@($sup.VlanTags).Count -lt $requiredTags) {
        throw "Network.Supervised.VlanTags must provide at least $requiredTags tag(s) for the enabled supervised stack(s)."
    }
    foreach ($tag in $sup.VlanTags) {
        if ([int]$tag -lt 1 -or [int]$tag -gt 4094) {
            throw "Network.Supervised.VlanTags contains an out-of-range tag '$tag' (valid range is 1-4094)."
        }
    }
    if ("$($sup.IpAddressFormat)" -notmatch '\{0\}') {
        throw "Network.Supervised.IpAddressFormat must contain '{0}' (substituted with the VLAN tag), e.g. '10.{0}.10.1'."
    }
    if (-not $sup.IpMask) {
        throw 'Network.Supervised.IpMask is required (e.g. 255.255.255.0).'
    }
    if ($fgStack) {
        if ([int]$sup.LifRole -notin @(1, 2, 3, 4, 8, 9, 10)) {
            throw "Network.Supervised.LifRole '$($sup.LifRole)' is invalid (valid values are 1,2,3,4,8,9,10)."
        }
        if ([int]$sup.LifSupportProtocol -notin @(0, 1, 2, 3, 4, 8, 64, 512)) {
            throw "Network.Supervised.LifSupportProtocol '$($sup.LifSupportProtocol)' is invalid (valid values are 0,1,2,3,4,8,64,512)."
        }
        if ([int]$sup.LifFailbackMode -notin @(0, 1, 2)) {
            throw "Network.Supervised.LifFailbackMode '$($sup.LifFailbackMode)' is invalid (valid values are 0,1,2)."
        }
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
