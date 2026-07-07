function Invoke-ReadValidation {
    $samples.System = Add-ValidationResult -Name 'Get-DMSystem' -ExpectedType 'OceanStorSystem' -Action {
        Get-DMSystem -WebSession $session
    }
    $samples.Disks = Add-ValidationResult -Name 'Get-DMdisk' -ExpectedType 'OceanStorDisks' -Action {
        Get-DMdisk -WebSession $session
    }
    $samples.Hosts = Add-ValidationResult -Name 'Get-DMhost' -ExpectedType 'OceanStorHost' -Action {
        Get-DMhost -WebSession $session
    }
    $samples.Luns = Add-ValidationResult -Name 'Get-DMlun' -Action {
        Get-DMlun -WebSession $session
    }
    Add-ValidationResult -Name 'Get-DMLunSnapshot' -ExpectedType 'OceanstorLunSnapshot' -Action {
        Get-DMLunSnapshot -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMHyperCDPSchedule' -ExpectedType 'OceanstorHyperCDPSchedule' -Action {
        Get-DMHyperCDPSchedule -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMProtectionGroup' -ExpectedType 'OceanstorProtectionGroup' -Action {
        Get-DMProtectionGroup -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMQosPolicy' -ExpectedType 'OceanstorQosPolicy' -Action {
        Get-DMQosPolicy -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMSnapshotConsistencyGroup' -ExpectedType 'OceanstorSnapshotConsistencyGroup' -Action {
        Get-DMSnapshotConsistencyGroup -WebSession $session
    } | Out-Null
    $samples.Workloads = Add-ValidationResult -Name 'Get-DMWorkLoadType' -ExpectedType 'OceanStorWorkload' -Action {
        Get-DMWorkLoadType -WebSession $session
    }

    Add-ValidationResult -Name 'Get-DMAlarm' -ExpectedType 'OceanStorAlarm' -Action {
        Get-DMAlarm -WebSession $session -AlarmStatus Unrecovered
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMbbu' -ExpectedType 'OceanStorBBU' -Action {
        Get-DMbbu -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMController' -ExpectedType 'OceanStorController' -Action {
        Get-DMController -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMEnclosure' -ExpectedType 'OceanStorEnclosure' -Action {
        Get-DMEnclosure -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMInterfaceModule' -ExpectedType 'OceanstorInterfaceModule' -Action {
        Get-DMInterfaceModule -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMdisk:Coffer' -ExpectedType 'OceanStorDisks' -Action {
        Get-DMdisk -WebSession $session -Coffer
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMdisk:Free' -ExpectedType 'OceanStorDisks' -Action {
        Get-DMdisk -WebSession $session -Free
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMdnsServer' -ExpectedType 'Hashtable' -Action {
        Get-DMdnsServer -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMNtpServer' -ExpectedType 'OceanStorNtpConfig' -Action {
        Get-DMNtpServer -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMNtpStatus' -ExpectedType 'OceanStorNtpStatus' -Action {
        Get-DMNtpStatus -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMSnmpConfig' -ExpectedType 'OceanStorSnmpConfig' -Action {
        Get-DMSnmpConfig -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMSnmpSecurityPolicy' -ExpectedType 'OceanStorSnmpSecurityPolicy' -Action {
        Get-DMSnmpSecurityPolicy -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMSnmpTrapServer' -ExpectedType 'OceanStorSnmpTrapServer' -Action {
        Get-DMSnmpTrapServer -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMSnmpUsmUser' -ExpectedType 'OceanStorSnmpUsmUser' -Action {
        Get-DMSnmpUsmUser -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMSyslogNotification' -ExpectedType 'OceanStorSyslogNotification' -Action {
        Get-DMSyslogNotification -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMLocalUser' -ExpectedType 'OceanStorLocalUser' -Action {
        Get-DMLocalUser -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMRole' -ExpectedType 'OceanStorRole' -Action {
        Get-DMRole -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMRolePermission' -ExpectedType 'OceanStorRolePermission' -Action {
        Get-DMRolePermission -WebSession $session -RoleOwnerGroup '1'
    } | Out-Null
    $samples.FileSystems = Add-ValidationResult -Name 'Get-DMFileSystem' -ExpectedType 'OceanstorFileSystem' -Action {
        Get-DMFileSystem -WebSession $session
    }
    if ($samples.FileSystems.Count -gt 0) {
        Add-ValidationResult -Name 'Get-DMFileSystemSnapshot' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
            Get-DMFileSystemSnapshot -WebSession $session -FileSystemName $samples.FileSystems[0].Name
        } | Out-Null
    }
    Add-ValidationResult -Name 'Get-DMhostGroup' -ExpectedType 'OceanStorHostGroup' -Action {
        Get-DMhostGroup -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMPortGroup' -ExpectedType 'OceanstorPortGroup' -Action {
        Get-DMPortGroup -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMMappingView' -ExpectedType 'OceanStorMappingView' -Action {
        Get-DMMappingView -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMLif' -ExpectedType 'OceanStorLIF' -Action {
        Get-DMLif -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMFailoverGroup' -ExpectedType 'OceanStorFailoverGroup' -Action {
        Get-DMFailoverGroup -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMLLDPWorkingMode' -ExpectedType 'PSCustomObject' -Action {
        Get-DMLLDPWorkingMode -WebSession $session
    } | Out-Null
    $samples.LunGroups = Add-ValidationResult -Name 'Get-DMlunGroup' -ExpectedType 'OceanStorLunGroup' -Action {
        Get-DMlunGroup -WebSession $session
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
    Add-ValidationResult -Name 'Get-DMShare:CIFS' -ExpectedType 'OceanStorCIFSShare' -Action {
        Get-DMShare -WebSession $session -ShareType CIFS
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMShare:NFS' -ExpectedType 'OceanStorNFSShare' -Action {
        Get-DMShare -WebSession $session -ShareType NFS
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMstoragePool' -ExpectedType 'OceanStorStoragePool' -Action {
        Get-DMstoragePool -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMvLan' -ExpectedType 'OceanStorvLan' -Action {
        Get-DMvLan -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMvStore' -ExpectedType 'OceanStorvStore' -Action {
        Get-DMvStore -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMHostInitiator:FibreChannel' -ExpectedType 'OceanstorHostinitiatorFC' -Action {
        Get-DMHostInitiator -WebSession $session -InitiatorType FibreChannel -All
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMFiberChannelInitiator' -ExpectedType 'OceanstorHostinitiatorFC' -Action {
        Get-DMFiberChannelInitiator -WebSession $session
    } | Out-Null
    $samples.IscsiInitiators = Add-ValidationResult -Name 'Get-DMHostInitiator:ISCSI' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
        Get-DMHostInitiator -WebSession $session -InitiatorType ISCSI -All
    }
    Add-ValidationResult -Name 'Get-DMIscsiInitiator' -ExpectedType 'OceanstorHostinitiatorISCSI' -Action {
        Get-DMIscsiInitiator -WebSession $session
    } | Out-Null
    Add-ValidationResult -Name 'Get-DMNvmeInitiator' -ExpectedType 'OceanstorHostinitiatorNVMe' -Action {
        Get-DMNvmeInitiator -WebSession $session
    } | Out-Null

    if ($samples.Disks.Count -gt 0) {
        $disk = $samples.Disks[0]
        Add-ValidationResult -Name 'Get-DMdisk:ByLocation' -ExpectedType 'OceanStorDisks' -Action {
            Get-DMdisk -WebSession $session -Location $disk.location
        } | Out-Null

        if ($disk.poolId) {
            Add-ValidationResult -Name 'Get-DMdisk:ByStoragePoolId' -ExpectedType 'OceanStorDisks' -Action {
                Get-DMdisk -WebSession $session -StoragePoolId $disk.poolId
            } | Out-Null
        }
        if ($disk.poolName) {
            Add-ValidationResult -Name 'Get-DMdisk:ByStoragePoolName' -ExpectedType 'OceanStorDisks' -Action {
                Get-DMdisk -WebSession $session -StoragePoolName $disk.poolName
            } | Out-Null
        }
    }

    if ($samples.Hosts.Count -gt 0) {
        $hostRecord = $samples.Hosts[0]
        Add-ValidationResult -Name 'Get-DMhost:ById' -ExpectedType 'OceanStorHost' -Action {
            Get-DMhost -WebSession $session -Id $hostRecord.id
        } | Out-Null
        Add-ValidationResult -Name 'Get-DMhost:ByName' -ExpectedType 'OceanStorHost' -Action {
            Get-DMhost -WebSession $session -Name $hostRecord.name
        } | Out-Null
        Add-ValidationResult -Name 'Get-DMhost:ByFilter' -ExpectedType 'OceanStorHost' -Action {
            Get-DMhost -WebSession $session -Filter Name -Value $hostRecord.name
        } | Out-Null

        if ($hostRecord.'Parent Id') {
            Add-ValidationResult -Name 'Get-DMhost:ByHostGroupId' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhost -WebSession $session -HostGroupId $hostRecord.'Parent Id'
            } | Out-Null
        }
        if ($hostRecord.'Parent Name') {
            Add-ValidationResult -Name 'Get-DMhost:ByHostGroupName' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhost -WebSession $session -HostGroupName $hostRecord.'Parent Name'
            } | Out-Null
        }
        Add-ValidationResult -Name 'Get-DMHostLink:FC' -ExpectedType 'OceanStorHostLink' -Action {
            Get-DMHostLink -WebSession $session -HostId $hostRecord.Id -InitiatorType FC
        } | Out-Null
        $iscsiWithHost = @($samples.IscsiInitiators | Where-Object { $_.'Host Id' })[0]
        if ($iscsiWithHost) {
            Add-ValidationResult -Name 'Get-DMHostLink:ISCSI' -ExpectedType 'OceanStorHostLink' -Action {
                Get-DMHostLink -WebSession $session -HostId $iscsiWithHost.'Host Id' -InitiatorType ISCSI
            } | Out-Null
        }
    }

    if ($samples.Luns.Count -gt 0) {
        $lun = $samples.Luns[0]
        Add-ValidationResult -Name 'Get-DMlun:ByWWN' -Action {
            Get-DMlun -WebSession $session -WWN $lun.WWN
        } | Out-Null
        Add-ValidationResult -Name 'Get-DMlun:ByName' -Action {
            Get-DMlun -WebSession $session -Name $lun.Name
        } | Out-Null
        Add-ValidationResult -Name 'Get-DMlun:ByFilter' -Action {
            Get-DMlun -WebSession $session -Filter Name -Value $lun.Name
        } | Out-Null
    }

    if ($samples.Workloads.Count -gt 0) {
        $workload = $samples.Workloads[0]
        Add-ValidationResult -Name 'Get-DMWorkLoadTypebyFilter' -ExpectedType 'OceanStorWorkload' -Action {
            Get-DMWorkLoadTypebyFilter -WebSession $session -Filter Name -Keyword $workload.Name
        } | Out-Null
    }
    if ($samples.LunGroups.Count -gt 0) {
        Add-ValidationResult -Name 'Get-DMlun:ByLunGroup' -Action {
            Get-DMlun -WebSession $session -LunGroup $samples.LunGroups[0]
        } | Out-Null
    }
}
