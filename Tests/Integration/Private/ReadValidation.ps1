function Invoke-ReadValidation {
    $samples.System = Add-ValidationResult -Name 'Get-DMSystem' -ExpectedType 'OceanStorSystem' -Action {
        Get-DMSystem -WebSession $session
    }
    $samples.Disks = Add-ValidationResult -Name 'Get-DMdisks' -ExpectedType 'OceanStorDisks' -Action {
        Get-DMdisks -WebSession $session
    }
    $samples.Hosts = Add-ValidationResult -Name 'Get-DMhosts' -ExpectedType 'OceanStorHost' -Action {
        Get-DMhosts -WebSession $session
    }
    $samples.Luns = Add-ValidationResult -Name 'Get-DMluns' -Action {
        Get-DMluns -WebSession $session
    }
    Add-ValidationResult -Name 'Get-DMLunSnapshots' -ExpectedType 'OceanstorLunSnapshot' -Action {
        Get-DMLunSnapshots -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMProtectionGroup' -ExpectedType 'OceanstorProtectionGroup' -Action {
        Get-DMProtectionGroup -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMSnapshotConsistencyGroup' -ExpectedType 'OceanstorSnapshotConsistencyGroup' -Action {
        Get-DMSnapshotConsistencyGroup -WebSession $session
    } | Out-Null
    $samples.Workloads = Add-ValidationResult -Name 'Get-DMWorkLoadTypes' -ExpectedType 'OceanStorWorkload' -Action {
        Get-DMWorkLoadTypes -WebSession $session
    }

    Add-ValidationResult -Name 'Get-DMAlarms' -ExpectedType 'OceanStorAlarm' -Action {
        Get-DMAlarms -WebSession $session -AlarmStatus Unrecovered
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMbbus' -ExpectedType 'OceanStorBBU' -Action {
        Get-DMbbus -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMControllers' -ExpectedType 'OceanStorController' -Action {
        Get-DMControllers -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMEnclosures' -ExpectedType 'OceanStorEnclosure' -Action {
        Get-DMEnclosures -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMInterfaceModules' -ExpectedType 'OceanstorInterfaceModule' -Action {
        Get-DMInterfaceModules -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMcofferDisks' -ExpectedType 'OceanStorDisks' -Action {
        Get-DMcofferDisks -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMfreeDisks' -ExpectedType 'OceanStorDisks' -Action {
        Get-DMfreeDisks -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMdnsServer' -ExpectedType 'Hashtable' -Action {
        Get-DMdnsServer -WebSession $session
    } | Out-Null
    $samples.FileSystems = Add-ValidationResult -Name 'Get-DMFileSystem' -ExpectedType 'OceanstorFileSystem' -Action {
        Get-DMFileSystem -WebSession $session
    }
    if ($samples.FileSystems.Count -gt 0) {
        Add-ValidationResult -Name 'Get-DMFileSystemSnapshots' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
            Get-DMFileSystemSnapshots -WebSession $session -FileSystemName $samples.FileSystems[0].Name
        } | Out-Null
    }
    Add-ValidationResult -Name 'Get-DMhostGroups' -ExpectedType 'OceanStorHostGroup' -Action {
        Get-DMhostGroups -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMPortGroup' -ExpectedType 'OceanstorPortGroup' -Action {
        Get-DMPortGroup -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMMappingView' -ExpectedType 'OceanStorMappingView' -Action {
        Get-DMMappingView -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMLifs' -ExpectedType 'OceanStorLIF' -Action {
        Get-DMLifs -WebSession $session
    } | Out-Null
    $samples.LunGroups = Add-ValidationResult -Name 'Get-DMlunGroups' -ExpectedType 'OceanStorLunGroup' -Action {
        Get-DMlunGroups -WebSession $session
    }
    Add-ValidationResult -Name 'Get-DMnfsFileClient' -ExpectedType 'OceanstorNFSclient' -Action {
        Get-DMnfsFileClient -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMPortBond' -ExpectedType 'OceanStorPortBond' -Action {
        Get-DMPortBond -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMPortETH' -ExpectedType 'OceanStorPortETH' -Action {
        Get-DMPortETH -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMPortFc' -ExpectedType 'OceanStorPortFC' -Action {
        Get-DMPortFc -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMPortSAS' -ExpectedType 'OceanstorPortSAS' -Action {
        Get-DMPortSAS -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMShares:CIFS' -ExpectedType 'OceanStorCIFSShare' -Action {
        Get-DMShares -WebSession $session -ShareType CIFS
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMShares:NFS' -ExpectedType 'OceanStorNFSShare' -Action {
        Get-DMShares -WebSession $session -ShareType NFS
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMstoragePools' -ExpectedType 'OceanStorStoragePool' -Action {
        Get-DMstoragePools -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMvLans' -ExpectedType 'OceanStorvLan' -Action {
        Get-DMvLans -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMvStore' -ExpectedType 'OceanStorvStore' -Action {
        Get-DMvStore -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMHostInitiators:FibreChannel' -ExpectedType 'OceanstorHostinitiatorFC' -Action {
        Get-DMHostInitiators -WebSession $session -InitatorType FibreChannel -All
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMFiberChannelInitiator' -ExpectedType 'OceanstorHostinitiatorFC' -Action {
        Get-DMFiberChannelInitiator -WebSession $session
    } | Out-Null
    $samples.IscsiInitiators = Add-ValidationResult -Name 'Get-DMHostInitiators:ISCSI' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
        Get-DMHostInitiators -WebSession $session -InitatorType ISCSI -All
    }
    Add-ValidationResult -Name 'Get-DMIscsiInitiator' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
        Get-DMIscsiInitiator -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMNvmeInitiator' -ExpectedType 'OceanstorHostinitiatorNVMe' -Action {
        Get-DMNvmeInitiator -WebSession $session
    } | Out-Null

    if ($samples.Disks.Count -gt 0) {
        $disk = $samples.Disks[0]
        Add-ValidationResult -Name 'Get-DMDiskbyLocation' -ExpectedType 'OceanStorDisks' -Action {
            Get-DMDiskbyLocation -WebSession $session -Location $disk.location
        } | Out-Null

        if ($disk.poolId) {
            Add-ValidationResult -Name 'Get-DMdisksbyPoolId' -ExpectedType 'OceanStorDisks' -Action {
                Get-DMdisksbyPoolId -WebSession $session -PoolId $disk.poolId
            } | Out-Null
        }
        if ($disk.poolName) {
            Add-ValidationResult -Name 'Get-DMdisksbyPoolName' -ExpectedType 'OceanStorDisks' -Action {
                Get-DMdisksbyPoolName -WebSession $session -PoolName $disk.poolName
            } | Out-Null
        }
    }

    if ($samples.Hosts.Count -gt 0) {
        $hostRecord = $samples.Hosts[0]
        Add-ValidationResult -Name 'Get-DMhostsbyId' -ExpectedType 'OceanStorHost' -Action {
            Get-DMhostsbyId -WebSession $session -HostId $hostRecord.id
        } | Out-Null
        Add-ValidationResult -Name 'Get-DMhostsbyName' -ExpectedType 'OceanStorHost' -Action {
            Get-DMhostsbyName -WebSession $session -Name $hostRecord.name
        } | Out-Null

        if ($hostRecord.'Parent Id') {
            Add-ValidationResult -Name 'Get-DMhostsbyHostGroupId' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhostsbyHostGroupId -WebSession $session -HostGroupId $hostRecord.'Parent Id'
            } | Out-Null
        }
        if ($hostRecord.'Parent Name') {
            Add-ValidationResult -Name 'Get-DMhostsbyHostGroupName' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhostsbyHostGroupName -WebSession $session -HostGroupName $hostRecord.'Parent Name'
            } | Out-Null
        }
        Add-ValidationResult -Name 'Get-DMHostLinks:FC' -ExpectedType 'OceanStorHostLink' -Action {
            Get-DMHostLinks -WebSession $session -HostId $hostRecord.Id -InitiatorType FC
        } | Out-Null
        $iscsiWithHost = @($samples.IscsiInitiators | Where-Object { $_.'Host Id' })[0]
        if ($iscsiWithHost) {
            Add-ValidationResult -Name 'Get-DMHostLinks:ISCSI' -ExpectedType 'OceanStorHostLink' -Action {
                Get-DMHostLinks -WebSession $session -HostId $iscsiWithHost.'Host Id' -InitiatorType ISCSI
            } | Out-Null
        }
    }

    if ($samples.Luns.Count -gt 0) {
        $lun = $samples.Luns[0]
        Add-ValidationResult -Name 'Get-DMlunsByWWN' -Action {
            Get-DMlunsByWWN -WebSession $session -WWN $lun.WWN
        } | Out-Null
        Add-ValidationResult -Name 'Get-DMLunsbyFilter' -Action {
            Get-DMLunsbyFilter -WebSession $session -Filter Name -Keyword $lun.Name
        } | Out-Null
    }

    if ($samples.Workloads.Count -gt 0) {
        $workload = $samples.Workloads[0]
        Add-ValidationResult -Name 'Get-DMWorkLoadTypesbyFilter' -ExpectedType 'OceanStorWorkload' -Action {
            Get-DMWorkLoadTypesbyFilter -WebSession $session -Filter Name -Keyword $workload.Name
        } | Out-Null
    }
    if ($samples.LunGroups.Count -gt 0) {
        Add-ValidationResult -Name 'Get-DMlunsbyLunGroup' -Action {
            Get-DMlunsbyLunGroup -WebSession $session -LunGroup $samples.LunGroups[0]
        } | Out-Null
    }
}
