[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Hostname,

    [string]$ReportPath = (Join-Path $PSScriptRoot 'getter-integrity-last-result.json'),

    [string]$ConfigurationPath = (Join-Path $PSScriptRoot 'IntegrityValidationConfig.psd1'),

    [switch]$RunMutatingTests
)

$ErrorActionPreference = 'Stop'
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

    Export-ModuleMember -Function '*'
}

Import-Module $validationModule -Force

$checks = [System.Collections.Generic.List[object]]::new()
$samples = @{}
$owned = @{}
foreach ($kind in @('Lun', 'LunSnapshot', 'LunGroup', 'Host', 'HostGroup', 'FileSystem', 'FileSystemSnapshot', 'DTree', 'CifsShare', 'NfsShare', 'NfsClient', 'MappingView', 'PortGroup', 'FibreChannelInitiator', 'IscsiInitiator', 'NvmeInitiator')) {
    $owned[$kind] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
}

function Add-ValidationResult {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [string]$ExpectedType,
        [string]$Category = 'Read'
    )

    try {
        $rows = @(& $Action)
        $types = @($rows | ForEach-Object { $_.GetType().Name } | Sort-Object -Unique)
        $unexpected = if ($ExpectedType) { @($types | Where-Object { $_ -ne $ExpectedType }) } else { @() }
        $status = if ($rows.Count -eq 0) { 'NoData' } elseif ($unexpected.Count -gt 0) { 'UnexpectedType' } else { 'Passed' }

        $checks.Add([pscustomobject]@{
            Name         = $Name
            Category     = $Category
            Status       = $status
            Count        = $rows.Count
            ExpectedType = $ExpectedType
            ActualTypes  = $types
            Error        = $null
        })

        return $rows
    }
    catch {
        $checks.Add([pscustomobject]@{
            Name         = $Name
            Category     = $Category
            Status       = 'Failed'
            Count        = 0
            ExpectedType = $ExpectedType
            ActualTypes  = @()
            Error        = $_.Exception.Message
        })

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
        [scriptblock]$Action,
        [string]$ExpectedType
    )

    return Add-ValidationResult -Name $Name -Action {
        $result = @(& $Action)
        foreach ($item in $result) {
            if ($item.PSObject.Properties['Code'] -and $item.Code -ne 0) {
                throw "$Name returned REST error code $($item.Code)."
            }
        }
        return $result
    } -ExpectedType $ExpectedType -Category 'Mutation'
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
}

function Invoke-OwnedRemoval {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    if (-not $owned[$Kind].Contains($Identity)) {
        return
    }

    $result = @(Invoke-MutationStep -Name $Name -Action {
        Assert-TestOwnedResource -Kind $Kind -Identity $Identity
        & $Action
    })
    if ($result.Count -gt 0) {
        Complete-TestOwnedResource -Kind $Kind -Identity $Identity
    }
}

try {
    Write-Host "A credential prompt will open for validation of $Hostname. No credentials are read from or written to the configuration file."
    $session = connect-deviceManager -Hostname $Hostname -Return $true -Secure
    $checks.Add([pscustomobject]@{
        Name         = 'connect-deviceManager'
        Category     = 'Session'
        Status       = 'Passed'
        Count        = 1
        ExpectedType = 'OceanstorSession'
        ActualTypes  = @($session.GetType().Name)
        Error        = $null
    })

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
    Add-ValidationResult -Name 'get-DMHostInitiators:ISCSI' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
        get-DMHostInitiators -WebSession $session -InitatorType ISCSI -All
    } | Out-Null
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
        Add-ValidationResult -Name 'get-DMHostLinks:ISCSI' -ExpectedType 'OceanStorHostLink' -Action {
            get-DMHostLinks -WebSession $session -HostId $hostRecord.Id -InitiatorType ISCSI
        } | Out-Null
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

    $commandsRequiringUnsupportedOwnership = @(
        'New-DMProtectionGroup',
        'Remove-DMProtectionGroup',
        'New-DMSnapshotConsistencyGroup',
        'New-DMSnapshotConsistencyGroupCopy',
        'Enable-DMSnapshotConsistencyGroup',
        'Restart-DMSnapshotConsistencyGroup',
        'Restore-DMSnapshotConsistencyGroup',
        'Remove-DMSnapshotConsistencyGroup',
        'Add-DMPortToPortGroup',
        'Remove-DMPortFromPortGroup',
        'Remove-DMFiberChannelInitiatorFromHost',
        'Remove-DMIscsiInitiatorFromHost',
        'Remove-DMNvmeInitiatorFromHost',
        'set-DMdnsServer'
    )
    Add-SkippedResult -Name $commandsRequiringUnsupportedOwnership -Reason 'Safety rule: the command would create an object without a public cleanup command, or modify/remove an object that this run cannot create first.'

    if (-not $RunMutatingTests) {
        Add-SkippedResult -Name @(
            'new-DMLun', 'new-DMLunSnapshot', 'new-DMLunSnapshotCopy', 'Enable-DMLunSnapshot',
            'Restart-DMLunSnapshot', 'Resize-DMLunSnapshot', 'Restore-DMLunSnapshot', 'remove-DMLunSnapShot',
            'Remove-DMLun', 'new-DMFileSystem', 'new-DMdTree', 'Remove-DMDTree',
            'New-DMFileSystemSnapshot', 'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot',
            'new-DMnfsShare', 'new-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare',
            'Remove-DMFileSystem', 'New-DMPortGroup', 'New-DMMappingView',
            'Add-DMPortGroupToMappingView', 'Remove-DMPortGroupFromMappingView',
            'Remove-DMMappingView', 'Remove-DMPortGroup', 'New-DMFiberChannelInitiator',
            'Remove-DMFiberChannelInitiator', 'New-DMIscsiInitiator', 'Remove-DMIscsiInitiator',
            'New-DMNvmeInitiator', 'Remove-DMNvmeInitiator', 'New-DMCifsShare',
            'New-DMHost', 'New-DMHostGroup', 'Add-DMHostToHostGroup', 'Remove-DMHostFromHostGroup',
            'Remove-DMHost', 'Remove-DMHostGroup', 'New-DMLunGroup', 'Add-DMLunToLunGroup',
            'Remove-DMLunFromLunGroup', 'Remove-DMLunGroup', 'Add-DMHostGroupToMappingView',
            'Remove-DMHostGroupFromMappingView', 'Add-DMLunGroupToMappingView',
            'Remove-DMLunGroupFromMappingView'
        ) -Status 'NotRequested' -Reason 'Call the runner with -RunMutatingTests and enable the desired section in IntegrityValidationConfig.psd1.'
    }
    elseif (-not $configuration.AllowMutatingTests) {
        Add-SkippedResult -Name @('Test-owned mutation workflows') -Status 'NotConfigured' -Reason 'Set AllowMutatingTests = $true in IntegrityValidationConfig.psd1 to acknowledge creation and cleanup of test resources.'
    }
    else {
        Test-MutatingConfiguration
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
        $hostName = New-TestName -Suffix 'host'
        $hostGroupName = New-TestName -Suffix 'hostgroup'
        $lunGroupContainsLun = $false

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
                if ($configuration.Lun.ExpandedSnapshotCapacitySectors -gt 0) {
                    Invoke-MutationStep -Name 'Resize-DMLunSnapshot' -Action {
                        Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                        Resize-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName `
                            -UserCapacity $configuration.Lun.ExpandedSnapshotCapacitySectors -Confirm:$false
                    } | Out-Null
                }
                else {
                    Add-SkippedResult -Name 'Resize-DMLunSnapshot' -Status 'NotConfigured' -Reason 'Set Lun.ExpandedSnapshotCapacitySectors to a larger capacity to validate snapshot expansion.'
                }
                Invoke-MutationStep -Name 'Restore-DMLunSnapshot' -Action {
                    Assert-TestOwnedResource -Kind LunSnapshot -Identity $snapshotName
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Restore-DMLunSnapshot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
                } | Out-Null
            }

            Invoke-OwnedRemoval -Name 'remove-DMLunSnapShot:Copy' -Kind LunSnapshot -Identity $snapshotCopyName -Action {
                remove-DMLunSnapShot -WebSession $session -SnapShotName $snapshotCopyName -Confirm:$false
            }
            Invoke-OwnedRemoval -Name 'remove-DMLunSnapShot' -Kind LunSnapshot -Identity $snapshotName -Action {
                remove-DMLunSnapShot -WebSession $session -SnapShotName $snapshotName -Confirm:$false
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
            }
            if ($owned.Lun.Contains($lunName) -and $owned.LunGroup.Contains($lunGroupName)) {
                $associateLun = @(Invoke-MutationStep -Name 'Add-DMLunToLunGroup' -Action {
                    Assert-TestOwnedResource -Kind Lun -Identity $lunName
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Add-DMLunToLunGroup -WebSession $session -LunName $lunName -LunGroupName $lunGroupName -Confirm:$false
                })
                if ($associateLun.Count -gt 0) {
                    $lunGroupContainsLun = $true
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
            }
            $host = @(Invoke-MutationStep -Name 'New-DMHost' -ExpectedType 'OceanStorHost' -Action {
                if (@(get-DMhosts -WebSession $session | Where-Object Name -EQ $hostName).Count -gt 0) {
                    throw "A host named '$hostName' already exists; refusing to claim it as test-owned."
                }
                New-DMHost -WebSession $session -Name $hostName -OperatingSystem $configuration.Host.OperatingSystem `
                    -Description "Integrity validation run $runId"
            })
            if ($host.Count -gt 0 -and $host[0].Name -eq $hostName) {
                Register-TestOwnedResource -Kind Host -Identity $hostName
            }
            if ($owned.Host.Contains($hostName) -and $owned.HostGroup.Contains($hostGroupName)) {
                Invoke-MutationStep -Name 'Add-DMHostToHostGroup' -Action {
                    Assert-TestOwnedResource -Kind Host -Identity $hostName
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Add-DMHostToHostGroup -WebSession $session -HostName $hostName -HostGroupName $hostGroupName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Remove-DMHostFromHostGroup' -Action {
                    Assert-TestOwnedResource -Kind Host -Identity $hostName
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Remove-DMHostFromHostGroup -WebSession $session -HostName $hostName -HostGroupName $hostGroupName -Confirm:$false
                } | Out-Null
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
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableFileSystemSnapshot) {
                $fsSnapshot = @(Invoke-MutationStep -Name 'New-DMFileSystemSnapshot' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    New-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName `
                        -SnapshotName $fileSystemSnapshotName -Description "Integrity validation run $runId"
                })
                if ($fsSnapshot.Count -gt 0 -and $fsSnapshot[0].Name -eq $fileSystemSnapshotName) {
                    Register-TestOwnedResource -Kind FileSystemSnapshot -Identity $fileSystemSnapshotName
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
                    new-DMdTree -WebSession $session -FileSystemName $fileSystemName -DTreeName $dTreeName
                })
                if ($dTree.Count -gt 0) {
                    Register-TestOwnedResource -Kind DTree -Identity $dTreeName
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
                }
            }
            elseif (-not $configuration.Nas.EnableCifs) {
                Add-SkippedResult -Name 'New-DMCifsShare' -Status 'NotConfigured' -Reason 'Set Nas.EnableCifs = $true to create a CIFS share below the test-owned file system; it is cleaned up with that parent.'
            }

            Invoke-OwnedRemoval -Name 'Remove-DMNfsClient' -Kind NfsClient -Identity $configuration.Nas.NfsClientName -Action {
                Remove-DMNfsClient -WebSession $session -ClientName $configuration.Nas.NfsClientName -Confirm:$false
            }
            Invoke-OwnedRemoval -Name 'Remove-DMNfsShare' -Kind NfsShare -Identity $nfsSharePath -Action {
                Remove-DMNfsShare -WebSession $session -SharePath $nfsSharePath -Confirm:$false
            }
            Invoke-OwnedRemoval -Name 'Remove-DMDTree' -Kind DTree -Identity $dTreeName -Action {
                Remove-DMDTree -WebSession $session -FileSystemName $fileSystemName -DTreeName $dTreeName -Confirm:$false
            }
            Invoke-OwnedRemoval -Name 'Remove-DMFileSystemSnapshot' -Kind FileSystemSnapshot -Identity $fileSystemSnapshotName -Action {
                Remove-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName `
                    -SnapshotName $fileSystemSnapshotName -Confirm:$false
            }
            Invoke-OwnedRemoval -Name 'Remove-DMFileSystem' -Kind FileSystem -Identity $fileSystemName -Action {
                Remove-DMFileSystem -WebSession $session -FileSystemName $fileSystemName -Force -Confirm:$false
            }
            if (-not $owned.FileSystem.Contains($fileSystemName) -and $owned.CifsShare.Contains($cifsShareName)) {
                Complete-TestOwnedResource -Kind CifsShare -Identity $cifsShareName
            }
        }
        else {
            Add-SkippedResult -Name @(
                'new-DMFileSystem', 'new-DMdTree', 'Remove-DMDTree', 'New-DMFileSystemSnapshot',
                'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot', 'new-DMnfsShare',
                'new-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare', 'New-DMCifsShare', 'Remove-DMFileSystem'
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
            }
            $mappingView = @(Invoke-MutationStep -Name 'New-DMMappingView' -ExpectedType 'OceanStorMappingView' -Action {
                if (@(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $mappingViewName).Count -gt 0) {
                    throw "A mapping view named '$mappingViewName' already exists; refusing to claim it as test-owned."
                }
                New-DMMappingView -WebSession $session -Name $mappingViewName -Description "Integrity validation run $runId"
            })
            if ($mappingView.Count -gt 0 -and $mappingView[0].Name -eq $mappingViewName) {
                Register-TestOwnedResource -Kind MappingView -Identity $mappingViewName
            }
            if ($owned.PortGroup.Contains($portGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                Invoke-MutationStep -Name 'Add-DMPortGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMPortGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -PortGroupName $portGroupName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Remove-DMPortGroupFromMappingView' -Action {
                    Assert-TestOwnedResource -Kind PortGroup -Identity $portGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Remove-DMPortGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -PortGroupName $portGroupName -Confirm:$false
                } | Out-Null
            }
            if ($owned.HostGroup.Contains($hostGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                Invoke-MutationStep -Name 'Add-DMHostGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMHostGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -HostGroupName $hostGroupName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Remove-DMHostGroupFromMappingView' -Action {
                    Assert-TestOwnedResource -Kind HostGroup -Identity $hostGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Remove-DMHostGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -HostGroupName $hostGroupName -Confirm:$false
                } | Out-Null
            }
            else {
                Add-SkippedResult -Name @('Add-DMHostGroupToMappingView', 'Remove-DMHostGroupFromMappingView') `
                    -Status 'NotConfigured' -Reason 'Enable Host and Mapping workflows so both mapped resources are test-owned.'
            }
            if ($owned.LunGroup.Contains($lunGroupName) -and $owned.MappingView.Contains($mappingViewName)) {
                Invoke-MutationStep -Name 'Add-DMLunGroupToMappingView' -Action {
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Add-DMLunGroupToMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -LunGroupName $lunGroupName -Confirm:$false
                } | Out-Null
                Invoke-MutationStep -Name 'Remove-DMLunGroupFromMappingView' -Action {
                    Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                    Assert-TestOwnedResource -Kind MappingView -Identity $mappingViewName
                    Remove-DMLunGroupFromMappingView -WebSession $session -MappingViewName $mappingViewName `
                        -LunGroupName $lunGroupName -Confirm:$false
                } | Out-Null
            }
            else {
                Add-SkippedResult -Name @('Add-DMLunGroupToMappingView', 'Remove-DMLunGroupFromMappingView') `
                    -Status 'NotConfigured' -Reason 'Enable LunGroup and Mapping workflows so both mapped resources are test-owned.'
            }
            Invoke-OwnedRemoval -Name 'Remove-DMMappingView' -Kind MappingView -Identity $mappingViewName -Action {
                Remove-DMMappingView -WebSession $session -MappingViewName $mappingViewName -Confirm:$false
            }
            Invoke-OwnedRemoval -Name 'Remove-DMPortGroup' -Kind PortGroup -Identity $portGroupName -Action {
                Remove-DMPortGroup -WebSession $session -PortGroupName $portGroupName -Confirm:$false
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

        if ($lunGroupContainsLun) {
            Invoke-MutationStep -Name 'Remove-DMLunFromLunGroup' -Action {
                Assert-TestOwnedResource -Kind Lun -Identity $lunName
                Assert-TestOwnedResource -Kind LunGroup -Identity $lunGroupName
                Remove-DMLunFromLunGroup -WebSession $session -LunName $lunName -LunGroupName $lunGroupName -Confirm:$false
            } | Out-Null
        }
        Invoke-OwnedRemoval -Name 'Remove-DMLunGroup' -Kind LunGroup -Identity $lunGroupName -Action {
            Remove-DMLunGroup -WebSession $session -LunGroupName $lunGroupName -Confirm:$false
        }
        Invoke-OwnedRemoval -Name 'Remove-DMLun' -Kind Lun -Identity $lunName -Action {
            Remove-DMLun -WebSession $session -LunName $lunName -ImmediateDelete -Confirm:$false
        }
        Invoke-OwnedRemoval -Name 'Remove-DMHost' -Kind Host -Identity $hostName -Action {
            Remove-DMHost -WebSession $session -HostName $hostName -Confirm:$false
        }
        Invoke-OwnedRemoval -Name 'Remove-DMHostGroup' -Kind HostGroup -Identity $hostGroupName -Action {
            Remove-DMHostGroup -WebSession $session -HostGroupName $hostGroupName -Confirm:$false
        }

        if ($configuration.Initiators.Enabled) {
            if ($configuration.Initiators.FibreChannelWWN) {
                $fc = @(Invoke-MutationStep -Name 'New-DMFiberChannelInitiator' -ExpectedType 'OceanstorHostinitiatorFC' -Action {
                    if (@(Get-DMFiberChannelInitiator -WebSession $session | Where-Object Id -EQ $configuration.Initiators.FibreChannelWWN).Count -gt 0) {
                        throw 'The configured Fibre Channel WWN already exists; refusing to modify it.'
                    }
                    New-DMFiberChannelInitiator -WebSession $session -WWN $configuration.Initiators.FibreChannelWWN
                })
                if ($fc.Count -gt 0 -and $fc[0].Id -eq $configuration.Initiators.FibreChannelWWN) {
                    Register-TestOwnedResource -Kind FibreChannelInitiator -Identity $configuration.Initiators.FibreChannelWWN
                }
                Invoke-OwnedRemoval -Name 'Remove-DMFiberChannelInitiator' -Kind FibreChannelInitiator `
                    -Identity $configuration.Initiators.FibreChannelWWN -Action {
                        Remove-DMFiberChannelInitiator -WebSession $session -WWN $configuration.Initiators.FibreChannelWWN -Confirm:$false
                    }
            }
            else {
                Add-SkippedResult -Name @('New-DMFiberChannelInitiator', 'Remove-DMFiberChannelInitiator') `
                    -Status 'NotConfigured' -Reason 'Provide Initiators.FibreChannelWWN to validate a free FC initiator lifecycle.'
            }
            if ($configuration.Initiators.IscsiIdentifier) {
                $iscsi = @(Invoke-MutationStep -Name 'New-DMIscsiInitiator' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
                    if (@(Get-DMIscsiInitiator -WebSession $session | Where-Object Id -EQ $configuration.Initiators.IscsiIdentifier).Count -gt 0) {
                        throw 'The configured iSCSI identifier already exists; refusing to modify it.'
                    }
                    New-DMIscsiInitiator -WebSession $session -Identifier $configuration.Initiators.IscsiIdentifier
                })
                if ($iscsi.Count -gt 0 -and $iscsi[0].Id -eq $configuration.Initiators.IscsiIdentifier) {
                    Register-TestOwnedResource -Kind IscsiInitiator -Identity $configuration.Initiators.IscsiIdentifier
                }
                Invoke-OwnedRemoval -Name 'Remove-DMIscsiInitiator' -Kind IscsiInitiator `
                    -Identity $configuration.Initiators.IscsiIdentifier -Action {
                        Remove-DMIscsiInitiator -WebSession $session -Identifier $configuration.Initiators.IscsiIdentifier -Confirm:$false
                    }
            }
            else {
                Add-SkippedResult -Name @('New-DMIscsiInitiator', 'Remove-DMIscsiInitiator') `
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
                }
                Invoke-OwnedRemoval -Name 'Remove-DMNvmeInitiator' -Kind NvmeInitiator `
                    -Identity $configuration.Initiators.NvmeNqn -Action {
                        Remove-DMNvmeInitiator -WebSession $session -Nqn $configuration.Initiators.NvmeNqn -Confirm:$false
                    }
            }
            else {
                Add-SkippedResult -Name @('New-DMNvmeInitiator', 'Remove-DMNvmeInitiator') `
                    -Status 'NotConfigured' -Reason 'Provide Initiators.NvmeNqn to validate a free NVMe initiator lifecycle.'
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMFiberChannelInitiator', 'Remove-DMFiberChannelInitiator',
                'New-DMIscsiInitiator', 'Remove-DMIscsiInitiator',
                'New-DMNvmeInitiator', 'Remove-DMNvmeInitiator'
            ) -Status 'NotConfigured' -Reason 'Set Initiators.Enabled = $true and supply unused initiator identities to run these lifecycles.'
        }
    }

    Add-SkippedResult -Name @('export-DeviceManager', 'export-DMInventory', 'export-DMStorageToExcel') `
        -Status 'NotConfigured' -Reason 'Export validation needs local output/report configuration and does not change array resources.'

    $representedCommands = @($checks.Name | ForEach-Object { ($_ -split ':')[0] } | Sort-Object -Unique)
    $unrepresentedCommands = @(
        Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Public') -Filter '*.ps1' |
            Select-Object -ExpandProperty BaseName |
            Where-Object { $representedCommands -notcontains $_ }
    )
    if ($unrepresentedCommands.Count -gt 0) {
        Add-SkippedResult -Name $unrepresentedCommands -Status 'NotExecuted' `
            -Reason 'This command did not have the prerequisite live data or an enabled safe lifecycle during this run.'
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
        Mode        = if ($RunMutatingTests) { 'GET validation and opt-in test-owned mutation workflows' } else { 'Read-only GET validation; mutation workflows not requested' }
        RunId       = $runId
        Passed      = @($checks | Where-Object Status -eq 'Passed').Count
        NoData      = @($checks | Where-Object Status -eq 'NoData').Count
        Skipped     = @($checks | Where-Object Status -in @('SkippedUnsafe', 'NotConfigured', 'NotRequested', 'NotExecuted')).Count
        Failed      = @($checks | Where-Object Status -in @('Failed', 'UnexpectedType')).Count
        RemainingTestOwnedResources = $remainingOwned
        Checks      = $checks
    }

    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath
    $report | Format-List Hostname, RunAt, Mode, RunId, Passed, NoData, Skipped, Failed, RemainingTestOwnedResources
    $checks | Format-Table Category, Name, Status, Count, ExpectedType, ActualTypes, Error -AutoSize
}
finally {
    Remove-Module -Name OceanstorLiveGetterValidation -Force -ErrorAction SilentlyContinue
}
