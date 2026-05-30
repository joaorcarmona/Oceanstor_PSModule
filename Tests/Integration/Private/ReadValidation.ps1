function Invoke-ReadValidation {
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
}
