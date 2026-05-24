[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Hostname,

    [string]$ReportPath = (Join-Path $PSScriptRoot 'getter-integrity-last-result.json'),

    [string]$MutationLogPath = (Join-Path $PSScriptRoot 'mutation-trace-last-result.json'),

    [string]$ConfigurationPath = (Join-Path $PSScriptRoot 'IntegrityValidationConfig.psd1'),

    [switch]$RunMutatingTests,

    [switch]$NoProgress,

    [switch]$ShowTestExecution
)

$ErrorActionPreference = 'Stop'
$runStartedAt = Get-Date
$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
$runId = Get-Date -Format 'yyyyMMddHHmmss'
$moduleRoot = Join-Path (Split-Path -Parent $PSScriptRoot) '..\POSH-Oceanstor'
$moduleRoot = (Resolve-Path -LiteralPath $moduleRoot).Path

$validationModule = New-Module -Name OceanstorLiveGetterValidation -ArgumentList $moduleRoot -ScriptBlock {
    param($root)

    Get-ChildItem -LiteralPath (Join-Path $root 'Private') -Filter 'class-*.ps1' |
        ForEach-Object { . $_.FullName }

    foreach ($privateHelper in @(
        'get-DMparsedElabel.ps1',
        'get-DMPortGroupCandidates.ps1',
        'invoke-DeviceManager.ps1',
        'Set-DMHostInitiators.ps1',
        'validate-WWNAddress.ps1',
        'write-DMError.ps1'
    )) {
        . (Join-Path $root "Private\$privateHelper")
    }

    Get-ChildItem -LiteralPath (Join-Path $root 'Public') -Filter '*.ps1' |
        ForEach-Object { . $_.FullName }

    function Enable-DMValidationRequestTrace {
        param([System.Collections.Generic.List[object]]$Sink)

        $script:DeviceManagerTraceSink = $Sink
        $script:DeviceManagerTraceAction = {
            param($entry)
            [void]$script:DeviceManagerTraceSink.Add($entry)
        }
    }

    function Set-DMValidationRequestTraceContext {
        param(
            [string]$Name,
            [string]$Category
        )

        $script:DeviceManagerTraceContext = if ($Name) {
            [pscustomobject]@{ Name = $Name; Category = $Category }
        }
        else {
            $null
        }
    }

    Export-ModuleMember -Function '*'
}

Import-Module $validationModule -Force

$checks = [System.Collections.Generic.List[object]]::new()
$mutationRequests = [System.Collections.Generic.List[object]]::new()
$cleanupActions = [System.Collections.Generic.List[object]]::new()
$samples = @{}
$owned = @{}
foreach ($kind in @('Lun', 'LunSnapshot', 'LunGroup', 'ProtectionGroup', 'SnapshotConsistencyGroup', 'Host', 'HostGroup', 'FileSystem', 'FileSystemSnapshot', 'DTree', 'CifsShare', 'NfsShare', 'NfsClient', 'MappingView', 'PortGroup', 'FibreChannelInitiator', 'IscsiInitiator', 'NvmeInitiator')) {
    $owned[$kind] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
}

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

try {
    Write-Host "A credential prompt will open for validation of $Hostname. No credentials are read from or written to the configuration file."
    Write-ValidationProgress -Name 'connect-deviceManager' -Category 'Session'
    $connectionStartedAt = Get-Date
    $session = connect-deviceManager -Hostname $Hostname -Return $true -Secure
    $connectionDurationMs = [math]::Round(((Get-Date) - $connectionStartedAt).TotalMilliseconds, 2)
    $checks.Add([pscustomobject]@{
        Name         = 'connect-deviceManager'
        Category     = 'Session'
        Status       = 'Passed'
        DurationMs   = $connectionDurationMs
        Count        = 1
        ExpectedType = 'OceanstorSession'
        ActualTypes  = @($session.GetType().Name)
        Error        = $null
    })
    Write-ValidationProgress -Name 'connect-deviceManager' -Category 'Session' -Status 'Passed' -DurationMs $connectionDurationMs

    $samples.System = Add-ValidationResult -Name 'get-DMSystem' -ExpectedType 'OceanStorSystem' -Action {
        get-DMSystem -WebSession $session
    }
    $samples.Disks = Add-ValidationResult -Name 'get-DMdisks' -ExpectedType 'OceanStorDisks' -Action {
        get-DMdisks -WebSession $session
    }
    $samples.Hosts = Add-ValidationResult -Name 'get-DMhosts' -ExpectedType 'OceanStorHost' -Action {
        get-DMhosts -WebSession $session
    }
    $samples.Luns = Add-ValidationResult -Name 'get-DMluns' -Action {
        get-DMluns -WebSession $session
    }
    Add-ValidationResult -Name 'get-DMLunSnapshots' -ExpectedType 'OceanstorLunSnapshot' -Action {
        get-DMLunSnapshots -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMProtectionGroup' -ExpectedType 'OceanstorProtectionGroup' -Action {
        Get-DMProtectionGroup -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMSnapshotConsistencyGroup' -ExpectedType 'OceanstorSnapshotConsistencyGroup' -Action {
        Get-DMSnapshotConsistencyGroup -WebSession $session
    } | Out-Null
    $samples.Workloads = Add-ValidationResult -Name 'get-DMWorkLoadTypes' -ExpectedType 'OceanStorWorkload' -Action {
        get-DMWorkLoadTypes -WebSession $session
    }

    Add-ValidationResult -Name 'get-DMAlarms' -ExpectedType 'OceanStorAlarm' -Action {
        get-DMAlarms -WebSession $session -AlarmStatus Unrecovered
    } | Out-Null
    Add-ValidationResult -Name 'get-DMbbus' -ExpectedType 'OceanStorBBU' -Action {
        get-DMbbus -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMControllers' -ExpectedType 'OceanStorController' -Action {
        get-DMControllers -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMEnclosures' -ExpectedType 'OceanStorEnclosure' -Action {
        get-DMEnclosures -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMInterfaceModules' -ExpectedType 'OceanstorInterfaceModule' -Action {
        get-DMInterfaceModules -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMcofferDisks' -ExpectedType 'OceanStorDisks' -Action {
        get-DMcofferDisks -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMfreeDisks' -ExpectedType 'OceanStorDisks' -Action {
        get-DMfreeDisks -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMdnsServer' -ExpectedType 'Hashtable' -Action {
        get-DMdnsServer -WebSession $session
    } | Out-Null
    $samples.FileSystems = Add-ValidationResult -Name 'get-DMFileSystem' -ExpectedType 'OceanstorFileSystem' -Action {
        get-DMFileSystem -WebSession $session
    }
    if ($samples.FileSystems.Count -gt 0) {
        Add-ValidationResult -Name 'Get-DMFileSystemSnapshots' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
            Get-DMFileSystemSnapshots -WebSession $session -FileSystemName $samples.FileSystems[0].Name
        } | Out-Null
    }
    Add-ValidationResult -Name 'get-DMhostGroups' -ExpectedType 'OceanStorHostGroup' -Action {
        get-DMhostGroups -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMPortGroup' -ExpectedType 'OceanstorPortGroup' -Action {
        Get-DMPortGroup -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMMappingView' -ExpectedType 'OceanStorMappingView' -Action {
        Get-DMMappingView -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMLifs' -ExpectedType 'OceanStorLIF' -Action {
        get-DMLifs -WebSession $session
    } | Out-Null
    $samples.LunGroups = Add-ValidationResult -Name 'get-DMlunGroups' -ExpectedType 'OceanStorLunGroup' -Action {
        get-DMlunGroups -WebSession $session
    }
    Add-ValidationResult -Name 'get-DMnfsFileClient' -ExpectedType 'OceanstorNFSclient' -Action {
        get-DMnfsFileClient -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMPortBond' -ExpectedType 'OceanStorPortBond' -Action {
        get-DMPortBond -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMPortETH' -ExpectedType 'OceanStorPortETH' -Action {
        get-DMPortETH -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMPortFc' -ExpectedType 'OceanStorPortFC' -Action {
        get-DMPortFc -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMPortSAS' -ExpectedType 'OceanstorPortSAS' -Action {
        get-DMPortSAS -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMShares:CIFS' -ExpectedType 'OceanStorCIFSShare' -Action {
        get-DMShares -WebSession $session -ShareType CIFS
    } | Out-Null
    Add-ValidationResult -Name 'get-DMShares:NFS' -ExpectedType 'OceanStorNFSShare' -Action {
        get-DMShares -WebSession $session -ShareType NFS
    } | Out-Null
    Add-ValidationResult -Name 'get-DMstoragePools' -ExpectedType 'OceanStorStoragePool' -Action {
        get-DMstoragePools -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMvLans' -ExpectedType 'OceanStorvLan' -Action {
        get-DMvLans -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMvStore' -ExpectedType 'OceanStorvStore' -Action {
        get-DMvStore -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'get-DMHostInitiators:FibreChannel' -ExpectedType 'OceanstorHostinitiatorFC' -Action {
        get-DMHostInitiators -WebSession $session -InitatorType FibreChannel -All
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMFiberChannelInitiator' -ExpectedType 'OceanstorHostinitiatorFC' -Action {
        Get-DMFiberChannelInitiator -WebSession $session
    } | Out-Null
    $samples.IscsiInitiators = Add-ValidationResult -Name 'get-DMHostInitiators:ISCSI' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
        get-DMHostInitiators -WebSession $session -InitatorType ISCSI -All
    }
    Add-ValidationResult -Name 'Get-DMIscsiInitiator' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
        Get-DMIscsiInitiator -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMNvmeInitiator' -ExpectedType 'OceanstorHostinitiatorNVMe' -Action {
        Get-DMNvmeInitiator -WebSession $session
    } | Out-Null

    if ($samples.Disks.Count -gt 0) {
        $disk = $samples.Disks[0]
        Add-ValidationResult -Name 'get-DMDiskbyLocation' -ExpectedType 'OceanStorDisks' -Action {
            get-DMDiskbyLocation -WebSession $session -Location $disk.location
        } | Out-Null

        if ($disk.poolId) {
            Add-ValidationResult -Name 'get-DMdisksbyPoolId' -ExpectedType 'OceanStorDisks' -Action {
                get-DMdisksbyPoolId -WebSession $session -PoolId $disk.poolId
            } | Out-Null
        }
        if ($disk.poolName) {
            Add-ValidationResult -Name 'get-DMdisksbyPoolName' -ExpectedType 'OceanStorDisks' -Action {
                get-DMdisksbyPoolName -WebSession $session -PoolName $disk.poolName
            } | Out-Null
        }
    }

    if ($samples.Hosts.Count -gt 0) {
        $hostRecord = $samples.Hosts[0]
        Add-ValidationResult -Name 'get-DMhostsbyId' -ExpectedType 'OceanStorHost' -Action {
            get-DMhostsbyId -WebSession $session -HostId $hostRecord.id
        } | Out-Null
        Add-ValidationResult -Name 'get-DMhostsbyName' -ExpectedType 'OceanStorHost' -Action {
            get-DMhostsbyName -WebSession $session -Name $hostRecord.name
        } | Out-Null

        if ($hostRecord.'Parent Id') {
            Add-ValidationResult -Name 'get-DMhostsbyHostGroupId' -ExpectedType 'OceanStorHost' -Action {
                get-DMhostsbyHostGroupId -WebSession $session -HostGroupId $hostRecord.'Parent Id'
            } | Out-Null
        }
        if ($hostRecord.'Parent Name') {
            Add-ValidationResult -Name 'get-DMhostsbyHostGroupName' -ExpectedType 'OceanStorHost' -Action {
                get-DMhostsbyHostGroupName -WebSession $session -HostGroupName $hostRecord.'Parent Name'
            } | Out-Null
        }
        Add-ValidationResult -Name 'get-DMHostLinks:FC' -ExpectedType 'OceanStorHostLink' -Action {
            get-DMHostLinks -WebSession $session -HostId $hostRecord.Id -InitiatorType FC
        } | Out-Null
        $iscsiWithHost = @($samples.IscsiInitiators | Where-Object { $_.'Host Id' })[0]
        if ($iscsiWithHost) {
            Add-ValidationResult -Name 'get-DMHostLinks:ISCSI' -ExpectedType 'OceanStorHostLink' -Action {
                get-DMHostLinks -WebSession $session -HostId $iscsiWithHost.'Host Id' -InitiatorType ISCSI
            } | Out-Null
        }
    }

    if ($samples.Luns.Count -gt 0) {
        $lun = $samples.Luns[0]
        Add-ValidationResult -Name 'get-DMlunsByWWN' -Action {
            get-DMlunsByWWN -WebSession $session -WWN $lun.WWN
        } | Out-Null
        Add-ValidationResult -Name 'get-DMLunsbyFilter' -Action {
            get-DMLunsbyFilter -WebSession $session -Filter Name -Keyword $lun.Name
        } | Out-Null
    }

    if ($samples.Workloads.Count -gt 0) {
        $workload = $samples.Workloads[0]
        Add-ValidationResult -Name 'get-DMWorkLoadTypesbyFilter' -ExpectedType 'OceanStorWorkload' -Action {
            get-DMWorkLoadTypesbyFilter -WebSession $session -Filter Name -Keyword $workload.Name
        } | Out-Null
    }
    if ($samples.LunGroups.Count -gt 0) {
        Add-ValidationResult -Name 'get-DMlunsbyLunGroup' -Action {
            get-DMlunsbyLunGroup -WebSession $session -LunGroup $samples.LunGroups[0]
        } | Out-Null
    }

    $excludedCommands = @(
        'Add-DMPortToPortGroup',
        'Remove-DMPortFromPortGroup',
        'Remove-DMNvmeInitiatorFromHost',
        'set-DMdnsServer',
        'export-DeviceManager',
        'export-DMInventory',
        'export-DMStorageToExcel'
    )

    if (-not $RunMutatingTests) {
        Add-SkippedResult -Name @(
            'new-DMLun', 'new-DMLunSnapshot', 'new-DMLunSnapshotCopy', 'Enable-DMLunSnapshot',
            'Restart-DMLunSnapshot', 'Resize-DMLunSnapshot', 'Restore-DMLunSnapshot', 'remove-DMLunSnapShot',
            'Remove-DMLun', 'new-DMFileSystem', 'new-DMdTree', 'Remove-DMDTree',
            'New-DMFileSystemSnapshot', 'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot',
            'new-DMnfsShare', 'new-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare',
            'New-DMCifsShare', 'Remove-DMCifsShare', 'Remove-DMFileSystem', 'New-DMPortGroup', 'New-DMMappingView',
            'Add-DMPortGroupToMappingView', 'Remove-DMPortGroupFromMappingView',
            'Remove-DMMappingView', 'Remove-DMPortGroup', 'New-DMFiberChannelInitiator',
            'Remove-DMFiberChannelInitiator', 'New-DMIscsiInitiator', 'Remove-DMIscsiInitiator',
            'New-DMNvmeInitiator', 'Remove-DMNvmeInitiator',
            'New-DMHost', 'New-DMHostGroup', 'Add-DMHostToHostGroup', 'Remove-DMHostFromHostGroup',
            'Remove-DMHost', 'Remove-DMHostGroup', 'New-DMLunGroup', 'Add-DMLunToLunGroup',
            'Remove-DMLunFromLunGroup', 'Remove-DMLunGroup', 'Add-DMHostGroupToMappingView',
            'Remove-DMHostGroupFromMappingView', 'Add-DMLunGroupToMappingView',
            'Remove-DMLunGroupFromMappingView', 'New-DMProtectionGroup', 'Remove-DMProtectionGroup',
            'New-DMSnapshotConsistencyGroup', 'New-DMSnapshotConsistencyGroupCopy',
            'Enable-DMSnapshotConsistencyGroup', 'Restart-DMSnapshotConsistencyGroup',
            'Restore-DMSnapshotConsistencyGroup', 'Remove-DMSnapshotConsistencyGroup',
            'Remove-DMFiberChannelInitiatorFromHost', 'Remove-DMIscsiInitiatorFromHost'
        ) -Status 'NotRequested' -Reason 'Call the runner with -RunMutatingTests and enable the desired section in IntegrityValidationConfig.psd1.'
    }
    elseif (-not $configuration.AllowMutatingTests) {
        Add-SkippedResult -Name @('Test-owned mutation workflows') -Status 'NotConfigured' -Reason 'Set AllowMutatingTests = $true in IntegrityValidationConfig.psd1 to acknowledge creation and cleanup of test resources.'
    }
    else {
        Test-MutatingConfiguration
        Enable-DMValidationRequestTrace -Sink $mutationRequests
        $lunName = New-TestName -Suffix 'lun'
        $snapshotName = New-TestName -Suffix 'snap'
        $snapshotCopyName = New-TestName -Suffix 'snapcopy'
        $fileSystemName = New-TestName -Suffix 'fs'
        $fileSystemSnapshotName = New-TestName -Suffix 'fssnap'
        $dTreeName = New-TestName -Suffix 'dtree'
        $cifsShareName = New-TestName -Suffix 'cifs'
        $nfsSharePath = "/$fileSystemName/"
        $mappingViewName = New-TestName -Suffix 'map'
        $portGroupName = New-TestName -Suffix 'ports'
        $lunGroupName = New-TestName -Suffix 'lungroup'
        $protectionGroupName = New-TestName -Suffix 'protect'
        $consistencyGroupName = New-TestName -Suffix 'cgsnap'
        $consistencyCopyName = New-TestName -Suffix 'cgcopy'
        $testHostName = New-TestName -Suffix 'host'
        $hostGroupName = New-TestName -Suffix 'hostgroup'
        $lunGroupContainsLun = $false
        $hostGroupContainsHost = $false
        $mappingContainsHostGroup = $false
        $mappingContainsLunGroup = $false
        $mappingContainsPortGroup = $false

        if ($configuration.Lun.Enabled) {
            $lun = @(Invoke-MutationStep -Name 'new-DMLun' -Action {
                if (@(get-DMluns -WebSession $session | Where-Object Name -EQ $lunName).Count -gt 0) {
                    throw "A LUN named '$lunName' already exists; refusing to claim it as test-owned."
                }
                new-DMLun -WebSession $session -LunName $lunName -Capacity $configuration.Lun.CapacityMB `
                    -StoragePoolID $configuration.StoragePoolId -AllocType $configuration.Lun.AllocationType `
                    -Description "Integrity validation run $runId"
            })
            if ($lun.Count -gt 0 -and $lun[0].Name -eq $lunName) {
                Register-TestOwnedResource -Kind Lun -Identity $lunName
                Register-CleanupAction -Name 'Remove-DMLun' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMLun' -Kind Lun -Identity $lunName -Action {
                        Remove-DMLun -WebSession $session -LunName $lunName -ImmediateDelete -Confirm:$false
                    }
                }
            }

            if ($owned.Lun.Contains($lunName)) {
                $snapshot = @(Invoke-MutationStep -Name 'new-DMLunSnapshot' -ExpectedType 'OceanstorLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    if (@(get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $snapshotName).Count -gt 0) {
                        throw "A LUN snapshot named '$snapshotName' already exists; refusing to claim it as test-owned."
                    }
                    new-DMLunSnapshot -WebSession $session -SnapshotName $snapshotName -SourceLunName $lunName `
                        -Description "Integrity validation run $runId"
                })
                if ($snapshot.Count -gt 0 -and $snapshot[0].Name -eq $snapshotName) {
                    Register-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Register-CleanupAction -Name 'remove-DMLunSnapShot' -Action {
                        Invoke-OwnedRemoval -Name 'remove-DMLunSnapShot' -Kind LunSnapshot -Identity $snapshotName -Action {
                            remove-DMLunSnapShot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                        }
                    }
                }
            }

            if ($owned.LunSnapshot.Contains($snapshotName)) {
                $copy = @(Invoke-MutationStep -Name 'new-DMLunSnapshotCopy' -ExpectedType 'OceanstorLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    if (@(get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $snapshotCopyName).Count -gt 0) {
                        throw "A LUN snapshot named '$snapshotCopyName' already exists; refusing to claim it as test-owned."
                    }
                    new-DMLunSnapshotCopy -WebSession $session -SourceSnapShotName $snapshotName `
                        -SnapshotCopyName $snapshotCopyName -Description "Integrity validation run $runId"
                })
                if ($copy.Count -gt 0 -and $copy[0].Name -eq $snapshotCopyName) {
                    Register-TestOwnedResource -Kind LunSnapshot -Identity $snapshotCopyName
                    Register-CleanupAction -Name 'remove-DMLunSnapShot:Copy' -Action {
                        Invoke-OwnedRemoval -Name 'remove-DMLunSnapShot:Copy' -Kind LunSnapshot -Identity $snapshotCopyName -Action {
                            remove-DMLunSnapShot -WebSession $session -SnapShotName $snapshotCopyName -Confirm:$false
                        }
                    }
                }

                Invoke-MutationStep -Name 'Enable-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Enable-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Restart-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Restart-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Restore-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Restore-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                } | Out-Null
                $expandedSnapshotCapacity = if ($configuration.Lun.ExpandedSnapshotCapacitySectors -gt 0) {
                    [uint64]$configuration.Lun.ExpandedSnapshotCapacitySectors
                }
                else {
                    [uint64]$snapshot[0].'User Capacity' + 2048
                }
                Invoke-MutationStep -Name 'Resize-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Resize-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName `
                        -UserCapacity $expandedSnapshotCapacity -Confirm:$false
                } | Out-Null
            }

        }
        else {
            Add-SkippedResult -Name @(
                'new-DMLun', 'new-DMLunSnapshot', 'new-DMLunSnapshotCopy', 'Enable-DMLunSnapshot',
                'Restart-DMLunSnapshot', 'Resize-DMLunSnapshot', 'Restore-DMLunSnapshot',
                'remove-DMLunSnapShot', 'Remove-DMLun'
            ) -Status 'NotConfigured' -Reason 'Set Lun.Enabled = $true and provide StoragePoolId to run the test-owned LUN workflow.'
        }

        if ($configuration.LunGroup.Enabled) {
            $lunGroup = @(Invoke-MutationStep -Name 'New-DMLunGroup' -ExpectedType 'OceanStorLunGroup' -Action {
                if (@(get-DMlunGroups -WebSession $session | Where-Object Name -EQ $lunGroupName).Count -gt 0) {
                    throw "A LUN group named '$lunGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMLunGroup -WebSession $session -Name $lunGroupName `
                    -ApplicationType $configuration.LunGroup.ApplicationType -Description "Integrity validation run $runId"
            })
            if ($lunGroup.Count -gt 0 -and $lunGroup[0].Name -eq $lunGroupName) {
                Register-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                Register-CleanupAction -Name 'Remove-DMLunGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMLunGroup' -Kind LunGroup -Identity $lunGroupName -Action {
                        Remove-DMLunGroup -WebSession $session -LunGroupName $lunGroupName -Confirm:$false
                    }
                }
            }
            if ($owned.Lun.Contains($lunName) -and $owned.LunGroup.Contains($lunGroupName)) {
                $associateLun = @(Invoke-MutationStep -Name 'Add-DMLunToLunGroup' -Action {
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Add-DMLunToLunGroup -WebSession $session -LunName $lunName -LunGroupName $lunGroupName -Confirm:$false
                })
                if ($associateLun.Count -gt 0) {
                    $lunGroupContainsLun = $true
                    Register-CleanupAction -Name 'Remove-DMLunFromLunGroup' -Action {
                        Invoke-MutationStep -Name 'Remove-DMLunFromLunGroup' -Action {
                            Assert-TestOwnedResource -Kind Lun -Identity $lunName
                            Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                            Remove-DMLunFromLunGroup -WebSession $session -LunName $lunName -LunGroupName $lunGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
        }
        else {
            Add-SkippedResult -Name @('New-DMLunGroup', 'Add-DMLunToLunGroup', 'Remove-DMLunFromLunGroup', 'Remove-DMLunGroup') `
                -Status 'NotConfigured' -Reason 'Set LunGroup.Enabled = $true with Lun.Enabled = $true to run the test-owned LUN group workflow.'
        }

        if ($configuration.Host.Enabled) {
            $hostGroup = @(Invoke-MutationStep -Name 'New-DMHostGroup' -ExpectedType 'OceanStorHostGroup' -Action {
                if (@(get-DMhostGroups -WebSession $session | Where-Object Name -EQ $hostGroupName).Count -gt 0) {
                    throw "A host group named '$hostGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMHostGroup -WebSession $session -Name $hostGroupName -Description "Integrity validation run $runId"
            })
            if ($hostGroup.Count -gt 0 -and $hostGroup[0].Name -eq $hostGroupName) {
                Register-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                Register-CleanupAction -Name 'Remove-DMHostGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMHostGroup' -Kind HostGroup -Identity $hostGroupName -Action {
                        Remove-DMHostGroup -WebSession $session -HostGroupName $hostGroupName -Confirm:$false
                    }
                }
            }
            $createdHost = @(Invoke-MutationStep -Name 'New-DMHost' -ExpectedType 'OceanStorHost' -Action {
                if (@(get-DMhosts -WebSession $session | Where-Object Name -EQ $testHostName).Count -gt 0) {
                    throw "A host named '$testHostName' already exists; refusing to claim it as test-owned."
                }
                New-DMHost -WebSession $session -Name $testHostName -OperatingSystem $configuration.Host.OperatingSystem `
                    -Description "Integrity validation run $runId"
            })
            if ($createdHost.Count -gt 0 -and $createdHost[0].Name -eq $testHostName) {
                Register-TestOwnedResource -Kind Host -Identity $testHostName
                Register-CleanupAction -Name 'Remove-DMHost' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMHost' -Kind Host -Identity $testHostName -Action {
                        Remove-DMHost -WebSession $session -HostName $testHostName -Confirm:$false
                    }
                }
            }
            if ($owned.Host.Contains($testHostName) -and $owned.HostGroup.Contains($hostGroupName)) {
                $hostAssociation = @(Invoke-MutationStep -Name 'Add-DMHostToHostGroup' -Action {
                    Assert-TestOwnedResource -Kind Host -Identity $testHostName
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Add-DMHostToHostGroup -WebSession $session -HostName $testHostName -HostGroupName $hostGroupName -Confirm:$false
                })
                if ($hostAssociation.Count -gt 0) {
                    $hostGroupContainsHost = $true
                    Register-CleanupAction -Name 'Remove-DMHostFromHostGroup' -Action {
                        Invoke-MutationStep -Name 'Remove-DMHostFromHostGroup' -Action {
                            Assert-TestOwnedResource -Kind Host -Identity $testHostName
                            Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                            Remove-DMHostFromHostGroup -WebSession $session -HostName $testHostName -HostGroupName $hostGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMHost', 'New-DMHostGroup', 'Add-DMHostToHostGroup',
                'Remove-DMHostFromHostGroup', 'Remove-DMHost', 'Remove-DMHostGroup'
            ) -Status 'NotConfigured' -Reason 'Set Host.Enabled = $true to run the test-owned host and host group workflow.'
        }

        if ($configuration.Nas.Enabled) {
            $fileSystem = @(Invoke-MutationStep -Name 'new-DMFileSystem' -ExpectedType 'OceanstorFileSystem' -Action {
                if (@(get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fileSystemName).Count -gt 0) {
                    throw "A file system named '$fileSystemName' already exists; refusing to claim it as test-owned."
                }
                new-DMFileSystem -WebSession $session -FileSystemName $fileSystemName `
                    -StoragePoolID $configuration.StoragePoolId -Capacity $configuration.Nas.FileSystemCapacityGB `
                    -Description "Integrity validation run $runId"
            })
            if ($fileSystem.Count -gt 0 -and $fileSystem[0].Name -eq $fileSystemName) {
                Register-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                Register-CleanupAction -Name 'Remove-DMFileSystem' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMFileSystem' -Kind FileSystem -Identity $fileSystemName -Action {
                        Remove-DMFileSystem -WebSession $session -FileSystemName $fileSystemName -Force -Confirm:$false
                    }
                }
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableFileSystemSnapshot) {
                $fsSnapshot = @(Invoke-MutationStep -Name 'New-DMFileSystemSnapshot' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    New-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName `
                        -SnapshotName $fileSystemSnapshotName -Description "Integrity validation run $runId"
                })
                if ($fsSnapshot.Count -gt 0 -and $fsSnapshot[0].Name -eq $fileSystemSnapshotName) {
                    Register-TestOwnedResource -Kind FileSystemSnapshot -Identity $fileSystemSnapshotName
                    Register-CleanupAction -Name 'Remove-DMFileSystemSnapshot' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMFileSystemSnapshot' -Kind FileSystemSnapshot -Identity $fileSystemSnapshotName -Action {
                            Remove-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName `
                                -SnapshotName $fileSystemSnapshotName -Confirm:$false
                        }
                    }
                    Invoke-MutationStep -Name 'Restore-DMFileSystemSnapshot' -Action {
                        Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                        Assert-TestOwnedResource -Kind FileSystemSnapshot -Identity $fileSystemSnapshotName
                        Restore-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName `
                            -SnapshotName $fileSystemSnapshotName -Confirm:$false
                    } | Out-Null
                }
            }
            elseif (-not $configuration.Nas.EnableFileSystemSnapshot) {
                Add-SkippedResult -Name @('New-DMFileSystemSnapshot', 'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot') `
                    -Status 'NotConfigured' -Reason 'Set Nas.EnableFileSystemSnapshot = $true to run the file-system snapshot workflow.'
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableDTree) {
                $dTree = @(Invoke-MutationStep -Name 'new-DMdTree' -ExpectedType 'OceanStorDtree' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    new-DMdTree -WebSession $session -FileSystemId $fileSystem[0].Id -DTreeName $dTreeName
                })
                if ($dTree.Count -gt 0) {
                    Register-TestOwnedResource -Kind DTree -Identity $dTreeName
                    Register-CleanupAction -Name 'Remove-DMDTree' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMDTree' -Kind DTree -Identity $dTreeName -Action {
                            Remove-DMDTree -WebSession $session -FileSystemName $fileSystemName -DTreeName $dTreeName -Confirm:$false
                        }
                    }
                }
            }
            elseif (-not $configuration.Nas.EnableDTree) {
                Add-SkippedResult -Name @('new-DMdTree', 'Remove-DMDTree') -Status 'NotConfigured' -Reason 'Set Nas.EnableDTree = $true to run the dTree workflow.'
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableNfs) {
                $nfsShare = @(Invoke-MutationStep -Name 'new-DMnfsShare' -ExpectedType 'OceanStorNFSShare' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    if (@(get-DMShares -WebSession $session -ShareType NFS | Where-Object 'Share Path' -EQ $nfsSharePath).Count -gt 0) {
                        throw "An NFS share using '$nfsSharePath' already exists; refusing to claim it as test-owned."
                    }
                    new-DMnfsShare -WebSession $session -SharePath $nfsSharePath -FileSystemId $fileSystem[0].Id
                })
                if ($nfsShare.Count -gt 0 -and $nfsShare[0].'Share Path' -eq $nfsSharePath) {
                    Register-TestOwnedResource -Kind NfsShare -Identity $nfsSharePath
                    Register-CleanupAction -Name 'Remove-DMNfsShare' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMNfsShare' -Kind NfsShare -Identity $nfsSharePath -Action {
                            Remove-DMNfsShare -WebSession $session -SharePath $nfsSharePath -Confirm:$false
                        }
                    }
                    $nfsClient = @(Invoke-MutationStep -Name 'new-DMnfsClient' -Action {
                        Assert-TestOwnedResource -Kind NfsShare -Identity $nfsSharePath
                        if (@(get-DMnfsFileClient -WebSession $session | Where-Object Name -EQ $configuration.Nas.NfsClientName).Count -gt 0) {
                            throw "An NFS client named '$($configuration.Nas.NfsClientName)' already exists; its removal could not be safely disambiguated."
                        }
                        new-DMnfsClient -WebSession $session -ClientName $configuration.Nas.NfsClientName `
                            -ShareId $nfsShare[0].Id
                    })
                    if ($nfsClient.Count -gt 0) {
                        Register-TestOwnedResource -Kind NfsClient -Identity $configuration.Nas.NfsClientName
                        Register-CleanupAction -Name 'Remove-DMNfsClient' -Action {
                            Invoke-OwnedRemoval -Name 'Remove-DMNfsClient' -Kind NfsClient -Identity $configuration.Nas.NfsClientName -Action {
                                Remove-DMNfsClient -WebSession $session -ClientName $configuration.Nas.NfsClientName -Confirm:$false
                            }
                        }
                    }
                }
            }
            elseif (-not $configuration.Nas.EnableNfs) {
                Add-SkippedResult -Name @('new-DMnfsShare', 'new-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare') `
                    -Status 'NotConfigured' -Reason 'Set Nas.EnableNfs = $true and provide Nas.NfsClientName to run NFS validation.'
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableCifs) {
                $cifsShare = @(Invoke-MutationStep -Name 'New-DMCifsShare' -ExpectedType 'OceanStorCIFSShare' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    if (@(get-DMShares -WebSession $session -ShareType CIFS | Where-Object Name -EQ $cifsShareName).Count -gt 0) {
                        throw "A CIFS share named '$cifsShareName' already exists; refusing to claim it as test-owned."
                    }
                    New-DMCifsShare -WebSession $session -ShareName $cifsShareName -FileSystemName $fileSystemName `
                        -Description "Integrity validation run $runId"
                })
                if ($cifsShare.Count -gt 0 -and $cifsShare[0].Name -eq $cifsShareName) {
                    Register-TestOwnedResource -Kind CifsShare -Identity $cifsShareName
                    Register-CleanupAction -Name 'Remove-DMCifsShare' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMCifsShare' -Kind CifsShare -Identity $cifsShareName -Action {
                            Remove-DMCifsShare -WebSession $session -ShareName $cifsShareName -Confirm:$false
                        }
                    }
                }
            }
            elseif (-not $configuration.Nas.EnableCifs) {
                Add-SkippedResult -Name @('New-DMCifsShare', 'Remove-DMCifsShare') -Status 'NotConfigured' -Reason 'Set Nas.EnableCifs = $true to validate a CIFS share below the test-owned file system.'
            }
        }
        else {
            Add-SkippedResult -Name @(
                'new-DMFileSystem', 'new-DMdTree', 'Remove-DMDTree', 'New-DMFileSystemSnapshot',
                'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot', 'new-DMnfsShare',
                'new-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare', 'New-DMCifsShare',
                'Remove-DMCifsShare', 'Remove-DMFileSystem'
            ) -Status 'NotConfigured' -Reason 'Set Nas.Enabled = $true and provide StoragePoolId to run the test-owned NAS workflow.'
        }

        if ($configuration.Mapping.Enabled) {
            $portGroup = @(Invoke-MutationStep -Name 'New-DMPortGroup' -ExpectedType 'OceanstorPortGroup' -Action {
                if (@(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $portGroupName).Count -gt 0) {
                    throw "A port group named '$portGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMPortGroup -WebSession $session -Name $portGroupName -Description "Integrity validation run $runId"
            })
            if ($portGroup.Count -gt 0 -and $portGroup[0].Name -eq $portGroupName) {
                Register-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                Register-CleanupAction -Name 'Remove-DMPortGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMPortGroup' -Kind PortGroup -Identity $portGroupName -Action {
                        Remove-DMPortGroup -WebSession $session -PortGroupName $portGroupName -Confirm:$false
                    }
                }
            }
            $mappingView = @(Invoke-MutationStep -Name 'New-DMMappingView' -ExpectedType 'OceanStorMappingView' -Action {
                if (@(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $mappingViewName).Count -gt 0) {
                    throw "A mapping view named '$mappingViewName' already exists; refusing to claim it as test-owned."
                }
                New-DMMappingView -WebSession $session -Name $mappingViewName -Description "Integrity validation run $runId"
            })
            if ($mappingView.Count -gt 0 -and $mappingView[0].Name -eq $mappingViewName) {
                Register-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                Register-CleanupAction -Name 'Remove-DMMappingView' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMMappingView' -Kind MappingView -Identity $mappingViewName -Action {
                        Remove-DMMappingView -WebSession $session -MappingViewName $mappingViewName -Confirm:$false
                    }
                }
            }
            if ($owned.HostGroup.Contains($hostGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                $mapHostGroup = @(Invoke-MutationStep -Name 'Add-DMHostGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMHostGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -HostGroupName $hostGroupName -Confirm:$false
                })
                if ($mapHostGroup.Count -gt 0) {
                    $mappingContainsHostGroup = $true
                    Register-CleanupAction -Name 'Remove-DMHostGroupFromMappingView' -Action {
                        Invoke-MutationStep -Name 'Remove-DMHostGroupFromMappingView' -Action {
                            Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                            Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                            Remove-DMHostGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                                -HostGroupName $hostGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
            else {
                $dependencyStatus = if ($configuration.Host.Enabled) { 'Blocked' } else { 'NotConfigured' }
                $dependencyReason = if ($configuration.Host.Enabled) {
                    'Host-group mapping could not run because a test-owned host group or mapping view was not created successfully.'
                }
                else {
                    'Enable Host and Mapping workflows so both mapped resources are test-owned.'
                }
                Add-SkippedResult -Name @('Add-DMHostGroupToMappingView', 'Remove-DMHostGroupFromMappingView') `
                    -Status $dependencyStatus -Reason $dependencyReason
            }
            if ($owned.LunGroup.Contains($lunGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                $mapLunGroup = @(Invoke-MutationStep -Name 'Add-DMLunGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMLunGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -LunGroupName $lunGroupName -Confirm:$false
                })
                if ($mapLunGroup.Count -gt 0) {
                    $mappingContainsLunGroup = $true
                    Register-CleanupAction -Name 'Remove-DMLunGroupFromMappingView' -Action {
                        Invoke-MutationStep -Name 'Remove-DMLunGroupFromMappingView' -Action {
                            Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                            Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                            Remove-DMLunGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                                -LunGroupName $lunGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
            else {
                $dependencyStatus = if ($configuration.LunGroup.Enabled) { 'Blocked' } else { 'NotConfigured' }
                $dependencyReason = if ($configuration.LunGroup.Enabled) {
                    'LUN-group mapping could not run because a test-owned LUN group or mapping view was not created successfully.'
                }
                else {
                    'Enable LunGroup and Mapping workflows so both mapped resources are test-owned.'
                }
                Add-SkippedResult -Name @('Add-DMLunGroupToMappingView', 'Remove-DMLunGroupFromMappingView') `
                    -Status $dependencyStatus -Reason $dependencyReason
            }
            if ($owned.PortGroup.Contains($portGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                $mapPortGroup = @(Invoke-MutationStep -Name 'Add-DMPortGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMPortGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -PortGroupName $portGroupName -Confirm:$false
                })
                if ($mapPortGroup.Count -gt 0) {
                    $mappingContainsPortGroup = $true
                    Register-CleanupAction -Name 'Remove-DMPortGroupFromMappingView' -Action {
                        Invoke-MutationStep -Name 'Remove-DMPortGroupFromMappingView' -Action {
                            Assert-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                            Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                            Remove-DMPortGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                                -PortGroupName $portGroupName -Confirm:$false
                        } | Out-Null
                    }
                }
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMPortGroup', 'New-DMMappingView', 'Add-DMPortGroupToMappingView',
                'Remove-DMPortGroupFromMappingView', 'Add-DMHostGroupToMappingView',
                'Remove-DMHostGroupFromMappingView', 'Add-DMLunGroupToMappingView',
                'Remove-DMLunGroupFromMappingView', 'Remove-DMMappingView', 'Remove-DMPortGroup'
            ) -Status 'NotConfigured' -Reason 'Set Mapping.Enabled = $true to run the test-owned mapping view workflow.'
        }

        if ($configuration.Protection.Enabled -and $lunGroupContainsLun) {
            $protectionGroup = @(Invoke-MutationStep -Name 'New-DMProtectionGroup' -ExpectedType 'OceanstorProtectionGroup' -Action {
                Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                if (@(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $protectionGroupName).Count -gt 0) {
                    throw "A protection group named '$protectionGroupName' already exists; refusing to claim it as test-owned."
                }
                New-DMProtectionGroup -WebSession $session -Name $protectionGroupName -LunGroupName $lunGroupName `
                    -Description "Integrity validation run $runId"
            })
            if ($protectionGroup.Count -gt 0 -and $protectionGroup[0].Name -eq $protectionGroupName) {
                Register-TestOwnedResource -Kind ProtectionGroup -Identity $protectionGroupName
                Register-CleanupAction -Name 'Remove-DMProtectionGroup' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMProtectionGroup' -Kind ProtectionGroup -Identity $protectionGroupName -Action {
                        Remove-DMProtectionGroup -WebSession $session -Name $protectionGroupName -Confirm:$false
                    }
                }
            }

            if ($owned.ProtectionGroup.Contains($protectionGroupName)) {
                $consistencyGroup = @(Invoke-MutationStep -Name 'New-DMSnapshotConsistencyGroup' -ExpectedType 'OceanstorSnapshotConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind ProtectionGroup -Identity $protectionGroupName
                    if (@(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $consistencyGroupName).Count -gt 0) {
                        throw "A snapshot consistency group named '$consistencyGroupName' already exists; refusing to claim it as test-owned."
                    }
                    New-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName `
                        -ProtectionGroupName $protectionGroupName -Description "Integrity validation run $runId"
                })
                if ($consistencyGroup.Count -gt 0 -and $consistencyGroup[0].Name -eq $consistencyGroupName) {
                    Register-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                    Register-CleanupAction -Name 'Remove-DMSnapshotConsistencyGroup' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMSnapshotConsistencyGroup' -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName -Action {
                            Wait-DMSnapshotConsistencyGroupReadyForRemoval -Name $consistencyGroupName
                            Remove-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName -Confirm:$false
                        }
                    }
                }
            }

            if ($owned.SnapshotConsistencyGroup.Contains($consistencyGroupName)) {
                $consistencyCopy = @(Invoke-MutationStep -Name 'New-DMSnapshotConsistencyGroupCopy' -ExpectedType 'OceanstorSnapshotConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                    New-DMSnapshotConsistencyGroupCopy -WebSession $session -SourceName $consistencyGroupName `
                        -Name $consistencyCopyName -Description "Integrity validation run $runId"
                })
                if ($consistencyCopy.Count -gt 0 -and $consistencyCopy[0].Name -eq $consistencyCopyName) {
                    Register-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyCopyName
                    Register-CleanupAction -Name 'Remove-DMSnapshotConsistencyGroup:Copy' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMSnapshotConsistencyGroup:Copy' -Kind SnapshotConsistencyGroup -Identity $consistencyCopyName -Action {
                            Remove-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyCopyName -Confirm:$false
                        }
                    }
                }
                $consistencyState = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $consistencyGroupName)[0]
                if ($consistencyState.'Running Status' -eq 'Unactivated') {
                    Invoke-MutationStep -Name 'Enable-DMSnapshotConsistencyGroup' -Action {
                        Assert-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                        Enable-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName -Confirm:$false
                    } | Out-Null
                }
                else {
                    Add-SkippedResult -Name 'Enable-DMSnapshotConsistencyGroup' -Status 'NotExecuted' `
                        -Reason "The newly created snapshot consistency group is '$($consistencyState.'Running Status')'; activation is only valid while it is Unactivated."
                }
                Invoke-MutationStep -Name 'Restart-DMSnapshotConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                    Restart-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Restore-DMSnapshotConsistencyGroup' -Action {
                    Assert-TestOwnedResource -Kind SnapshotConsistencyGroup -Identity $consistencyGroupName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Restore-DMSnapshotConsistencyGroup -WebSession $session -Name $consistencyGroupName -Confirm:$false
                } | Out-Null
            }

        }
        elseif (-not $configuration.Protection.Enabled) {
            Add-SkippedResult -Name @(
                'New-DMProtectionGroup', 'Remove-DMProtectionGroup', 'New-DMSnapshotConsistencyGroup',
                'New-DMSnapshotConsistencyGroupCopy', 'Enable-DMSnapshotConsistencyGroup',
                'Restart-DMSnapshotConsistencyGroup', 'Restore-DMSnapshotConsistencyGroup',
                'Remove-DMSnapshotConsistencyGroup'
            ) -Status 'NotConfigured' -Reason 'Set Protection.Enabled = $true with Lun and LunGroup enabled to run the test-owned protection workflow.'
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMProtectionGroup', 'Remove-DMProtectionGroup', 'New-DMSnapshotConsistencyGroup',
                'New-DMSnapshotConsistencyGroupCopy', 'Enable-DMSnapshotConsistencyGroup',
                'Restart-DMSnapshotConsistencyGroup', 'Restore-DMSnapshotConsistencyGroup',
                'Remove-DMSnapshotConsistencyGroup'
            ) -Status 'Blocked' -Reason 'Protection validation could not run because the test-owned LUN and LUN-group association was not created successfully.'
        }

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

        if ($owned.Lun.Contains($lunName)) {
            Add-MutationReadVerification -Name 'get-DMluns:Created' -Action {
                get-DMluns -WebSession $session | Where-Object Name -EQ $lunName
            } | Out-Null
        }
        if ($owned.LunSnapshot.Contains($snapshotName)) {
            Add-MutationReadVerification -Name 'get-DMLunSnapshots:Created' -ExpectedType 'OceanstorLunSnapshot' -Action {
                get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $snapshotName
            } | Out-Null
        }
        if ($owned.LunGroup.Contains($lunGroupName)) {
            Add-MutationReadVerification -Name 'get-DMlunGroups:Created' -ExpectedType 'OceanStorLunGroup' -Action {
                get-DMlunGroups -WebSession $session | Where-Object Name -EQ $lunGroupName
            } | Out-Null
        }
        if ($lunGroupContainsLun) {
            Add-MutationReadVerification -Name 'get-DMlunsbyLunGroup:Association' -Action {
                get-DMlunsbyLunGroup -WebSession $session -LunGroup $lunGroup[0] | Where-Object Name -EQ $lunName
            } | Out-Null
        }
        if ($owned.Host.Contains($testHostName)) {
            Add-MutationReadVerification -Name 'get-DMhosts:Created' -ExpectedType 'OceanStorHost' -Action {
                get-DMhosts -WebSession $session | Where-Object Name -EQ $testHostName
            } | Out-Null
        }
        if ($hostGroupContainsHost) {
            Add-MutationReadVerification -Name 'get-DMhostsbyHostGroupName:Association' -ExpectedType 'OceanStorHost' -Action {
                get-DMhostsbyHostGroupName -WebSession $session -HostGroupName $hostGroupName | Where-Object Name -EQ $testHostName
            } | Out-Null
        }
        if ($owned.FileSystem.Contains($fileSystemName)) {
            Add-MutationReadVerification -Name 'get-DMFileSystem:Created' -ExpectedType 'OceanstorFileSystem' -Action {
                get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fileSystemName
            } | Out-Null
        }
        if ($owned.FileSystemSnapshot.Contains($fileSystemSnapshotName)) {
            Add-MutationReadVerification -Name 'Get-DMFileSystemSnapshots:Created' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
                Get-DMFileSystemSnapshots -WebSession $session -FileSystemName $fileSystemName | Where-Object Name -EQ $fileSystemSnapshotName
            } | Out-Null
        }
        if ($owned.NfsShare.Contains($nfsSharePath)) {
            Add-MutationReadVerification -Name 'get-DMShares:NFS:Created' -ExpectedType 'OceanStorNFSShare' -Action {
                get-DMShares -WebSession $session -ShareType NFS | Where-Object 'Share Path' -EQ $nfsSharePath
            } | Out-Null
        }
        if ($owned.CifsShare.Contains($cifsShareName)) {
            Add-MutationReadVerification -Name 'get-DMShares:CIFS:Created' -ExpectedType 'OceanStorCIFSShare' -Action {
                get-DMShares -WebSession $session -ShareType CIFS | Where-Object Name -EQ $cifsShareName
            } | Out-Null
        }
        if ($owned.MappingView.Contains($mappingViewName)) {
            Add-MutationReadVerification -Name 'Get-DMMappingView:Created' -ExpectedType 'OceanStorMappingView' -Action {
                Get-DMMappingView -WebSession $session | Where-Object Name -EQ $mappingViewName
            } | Out-Null
        }
        if ($mappingContainsHostGroup) {
            Add-MutationReadVerification -Name 'Get-DMMappingView:HostGroupAssociation' -ExpectedType 'OceanStorMappingView' -Action {
                Get-DMMappingView -WebSession $session -HostGroupName $hostGroupName | Where-Object Name -EQ $mappingViewName
            } | Out-Null
        }
        if ($mappingContainsLunGroup) {
            Add-MutationReadVerification -Name 'Get-DMMappingView:LunGroupAssociation' -ExpectedType 'OceanStorMappingView' -Action {
                Get-DMMappingView -WebSession $session -LunGroupName $lunGroupName | Where-Object Name -EQ $mappingViewName
            } | Out-Null
        }
        if ($mappingContainsPortGroup) {
            Add-MutationReadVerification -Name 'Get-DMMappingView:PortGroupAssociation' -ExpectedType 'OceanStorMappingView' -Action {
                Get-DMMappingView -WebSession $session -PortGroupName $portGroupName | Where-Object Name -EQ $mappingViewName
            } | Out-Null
        }
        if ($owned.ProtectionGroup.Contains($protectionGroupName)) {
            Add-MutationReadVerification -Name 'Get-DMProtectionGroup:Created' -ExpectedType 'OceanstorProtectionGroup' -Action {
                Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $protectionGroupName
            } | Out-Null
        }
        if ($owned.SnapshotConsistencyGroup.Contains($consistencyGroupName)) {
            Add-MutationReadVerification -Name 'Get-DMSnapshotConsistencyGroup:Created' -ExpectedType 'OceanstorSnapshotConsistencyGroup' -Action {
                Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $consistencyGroupName
            } | Out-Null
        }

        Invoke-RegisteredCleanup
    }

    $representedCommands = @($checks.Name | ForEach-Object { ($_ -split ':')[0] } | Sort-Object -Unique)
    $unrepresentedCommands = @(
        Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Public') -Filter '*.ps1' |
            Select-Object -ExpandProperty BaseName |
            Where-Object { $representedCommands -notcontains $_ -and $excludedCommands -notcontains $_ }
    )
    if ($unrepresentedCommands.Count -gt 0) {
        $unrepresentedStatus = if ($RunMutatingTests -and $configuration.AllowMutatingTests) { 'Blocked' } else { 'NotExecuted' }
        $unrepresentedReason = if ($unrepresentedStatus -eq 'Blocked') {
            'This command could not run because its test-owned prerequisite resource was not created successfully during this run.'
        }
        else {
            'This command did not have the prerequisite live data or an enabled safe lifecycle during this run.'
        }
        Add-SkippedResult -Name $unrepresentedCommands -Status $unrepresentedStatus -Reason $unrepresentedReason
    }

    $remainingOwned = @(
        foreach ($kind in $owned.Keys) {
            foreach ($identity in $owned[$kind]) {
                "${kind}:$identity"
            }
        }
    )

    $report = [pscustomobject]@{
        Hostname    = $Hostname
        RunAt       = (Get-Date).ToString('o')
        DurationMs  = [math]::Round(((Get-Date) - $runStartedAt).TotalMilliseconds, 2)
        Mode        = if ($RunMutatingTests) { 'GET validation and opt-in test-owned mutation workflows' } else { 'Read-only GET validation; mutation workflows not requested' }
        RunId       = $runId
        Passed      = @($checks | Where-Object Status -eq 'Passed').Count
        NoData      = @($checks | Where-Object Status -eq 'NoData').Count
        Skipped     = @($checks | Where-Object Status -in @('SkippedUnsafe', 'NotConfigured', 'NotRequested', 'NotExecuted', 'Blocked')).Count
        Blocked     = @($checks | Where-Object Status -eq 'Blocked').Count
        Failed      = @($checks | Where-Object Status -in @('Failed', 'UnexpectedType')).Count
        MutationLogPath = if ($RunMutatingTests -and $configuration.AllowMutatingTests) { $MutationLogPath } else { $null }
        TracedMutationRequests = $mutationRequests.Count
        ExcludedCommands = $excludedCommands
        RemainingTestOwnedResources = $remainingOwned
        Checks      = $checks
    }

    if ($RunMutatingTests -and $configuration.AllowMutatingTests) {
        $mutationLog = [pscustomobject]@{
            Hostname    = $Hostname
            RunAt       = (Get-Date).ToString('o')
            RunId       = $runId
            ReportPath  = $ReportPath
            RequestCount = $mutationRequests.Count
            FailedChecks = @($checks | Where-Object { $_.Category -in @('Mutation', 'MutationRead') -and $_.Status -in @('Failed', 'UnexpectedType') })
            RemainingTestOwnedResources = $remainingOwned
            Requests    = $mutationRequests
        }
        $mutationLog | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $MutationLogPath
    }

    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath
    $report | Format-List Hostname, RunAt, DurationMs, Mode, RunId, Passed, NoData, Skipped, Blocked, Failed, MutationLogPath, TracedMutationRequests, ExcludedCommands, RemainingTestOwnedResources
    $checks | Format-Table Category, Name, Status, DurationMs, Count, ExpectedType, ActualTypes, Error -AutoSize
}
finally {
    if (-not $NoProgress) {
        Write-Progress -Id 1 -Activity "Validating OceanStor $Hostname" -Completed
    }
    Remove-Module -Name OceanstorLiveGetterValidation -Force -ErrorAction SilentlyContinue
}
