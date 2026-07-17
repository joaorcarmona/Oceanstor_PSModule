# Feature -> command map for POSH-Oceanstor's feature-gated command groups.
#
# Every public function exported by the module must appear in exactly ONE feature
# below. The FeatureMap Pester suite (Tests/Unit/Private/FeatureMap.Tests.ps1)
# fails whenever a FunctionsToExport entry is missing here, listed twice, or when a
# command listed here has no matching export -- so this file is the single source of
# truth for which commands belong to which feature.
#
# Per feature:
#   DefaultEnabled - built-in state when the user has no config override. Only
#                    HyperMetro and Replication ship disabled; everything else is on.
#   Locked         - (Core only) the feature can never be disabled.
#   Description    - shown by Get-DMFeature.
#   Commands       - the exported function names assigned to the feature.
#
# Disabled features are hidden by not exporting their commands (POSH-Oceanstor.psm1
# filters Export-ModuleMember against the effective feature state). Toggling a
# feature requires Import-Module -Force to take effect in an existing session.
@{
    Features = @{

        Core = @{
            DefaultEnabled = $true
            Locked         = $true
            Description    = 'Connection, system inventory, export, and feature-control cmdlets. Always available and cannot be disabled.'
            Commands       = @(
                'Connect-deviceManager'
                'Disconnect-deviceManager'
                'Get-DMSystem'
                'Export-DeviceManager'
                'Export-DMInventory'
                'Export-DMStorageToExcel'
                'Get-DMFeature'
                'Enable-DMFeature'
                'Disable-DMFeature'
            )
        }

        HyperMetro = @{
            DefaultEnabled = $false
            Description    = 'Block and file HyperMetro (active-active) plus quorum servers. Off by default: live validation needs a second array / quorum most environments do not expose.'
            Commands       = @(
                'Add-DMHyperMetroPairToConsistencyGroup'
                'Add-DMQuorumServerToHyperMetroDomain'
                'Get-DMFileHyperMetroDomain'
                'Get-DMHyperMetroConsistencyGroup'
                'Get-DMHyperMetroDomain'
                'Get-DMHyperMetroPair'
                'Get-DMQuorumServer'
                'Join-DMFileHyperMetroDomain'
                'New-DMFileHyperMetroDomain'
                'New-DMHyperMetroConsistencyGroup'
                'New-DMHyperMetroDomain'
                'New-DMHyperMetroPair'
                'Remove-DMFileHyperMetroDomain'
                'Remove-DMHyperMetroConsistencyGroup'
                'Remove-DMHyperMetroPair'
                'Remove-DMHyperMetroPairFromConsistencyGroup'
                'Remove-DMHyperMetroDomain'
                'Remove-DMQuorumServerFromHyperMetroDomain'
                'Set-DMHyperMetroConsistencyGroup'
                'Set-DMHyperMetroDomain'
                'Set-DMHyperMetroPair'
                'Set-DMHyperMetroPairPreferredPolicy'
                'Split-DMFileHyperMetroDomain'
                'Start-DMFileHyperMetroDomain'
                'Start-DMHyperMetroConsistencyGroup'
                'Start-DMHyperMetroPair'
                'Suspend-DMHyperMetroConsistencyGroup'
                'Suspend-DMHyperMetroPair'
                'Switch-DMFileHyperMetroDomain'
                'Switch-DMHyperMetroConsistencyGroup'
                'Switch-DMHyperMetroPairPriority'
                'Sync-DMHyperMetroConsistencyGroup'
                'Sync-DMHyperMetroPair'
            )
        }

        Replication = @{
            DefaultEnabled = $false
            Description    = 'Block and file remote replication, vStore pairs, and remote devices. Off by default: live validation needs a paired remote array.'
            Commands       = @(
                'Add-DMReplicationPairToConsistencyGroup'
                'Disable-DMFileSystemReplicationPairSecondaryProtection'
                'Disable-DMReplicationPairSecondaryProtection'
                'Enable-DMFileSystemReplicationPairSecondaryProtection'
                'Enable-DMReplicationPairSecondaryProtection'
                'Get-DMFileSystemReplicationPair'
                'Get-DMRemoteDevice'
                'Get-DMRemoteLun'
                'Get-DMReplicationConsistencyGroup'
                'Get-DMReplicationPair'
                'Get-DMVStorePair'
                'New-DMFileSystemReplicationPair'
                'New-DMReplicationConsistencyGroup'
                'New-DMReplicationPair'
                'New-DMVStorePair'
                'Remove-DMReplicationConsistencyGroup'
                'Remove-DMReplicationPair'
                'Remove-DMReplicationPairFromConsistencyGroup'
                'Remove-DMVStorePair'
                'Set-DMReplicationConsistencyGroup'
                'Set-DMReplicationPair'
                'Set-DMReplicationPairMode'
                'Set-DMVStorePair'
                'Set-DMFileSystemReplicationPairSecondaryReadOnly'
                'Split-DMVStorePair'
                'Split-DMReplicationConsistencyGroup'
                'Split-DMReplicationPair'
                'Switch-DMReplicationConsistencyGroup'
                'Switch-DMReplicationPair'
                'Switch-DMVStorePair'
                'Sync-DMReplicationConsistencyGroup'
                'Sync-DMReplicationPair'
                'Sync-DMVStorePair'
            )
        }

        Host = @{
            DefaultEnabled = $true
            Description    = 'Hosts, host groups, FC/iSCSI/NVMe initiators, and host links.'
            Commands       = @(
                'Add-DMHostToHostGroup'
                'Get-DMFiberChannelInitiator'
                'Get-DMhostGroup'
                'Get-DMHostInitiator'
                'Get-DMHostLink'
                'Get-DMhost'
                'Get-DMhostbyFilter'
                'Get-DMhostbyHostGroup'
                'Get-DMhostbyId'
                'Get-DMhostbyName'
                'Get-DMIscsiInitiator'
                'Get-DMNvmeInitiator'
                'New-DMFiberChannelInitiator'
                'New-DMHost'
                'New-DMHostGroup'
                'New-DMIscsiInitiator'
                'New-DMNvmeInitiator'
                'Remove-DMFiberChannelInitiator'
                'Remove-DMFiberChannelInitiatorFromHost'
                'Remove-DMHost'
                'Remove-DMHostFromHostGroup'
                'Remove-DMHostGroup'
                'Remove-DMIscsiInitiator'
                'Remove-DMIscsiInitiatorFromHost'
                'Remove-DMNvmeInitiator'
                'Remove-DMNvmeInitiatorFromHost'
                'Rename-DMHost'
                'Rename-DMHostGroup'
                'Set-DMHost'
                'Set-DMHostGroup'
            )
        }

        Lun = @{
            DefaultEnabled = $true
            Description    = 'LUN CRUD, LUN groups, and workload types.'
            Commands       = @(
                'Add-DMLunToLunGroup'
                'Get-DMlunGroup'
                'Get-DMlun'
                'Get-DMLunbyFilter'
                'Get-DMlunbyLunGroup'
                'Get-DMlunByName'
                'Get-DMlunByWWN'
                'Get-DMWorkLoadType'
                'Get-DMWorkLoadTypebyFilter'
                'New-DMLun'
                'New-DMLunGroup'
                'Remove-DMLun'
                'Remove-DMLunFromLunGroup'
                'Remove-DMLunGroup'
                'Rename-DMLun'
                'Rename-DMLunGroup'
                'Set-DMLun'
                'Set-DMLunGroup'
            )
        }

        Mapping = @{
            DefaultEnabled = $true
            Description    = 'Mapping views, port groups, and map/unmap operations.'
            Commands       = @(
                'Add-DMHostGroupToMappingView'
                'Add-DMLunGroupToMappingView'
                'Add-DMmapLunGroupToHost'
                'Add-DMmapLunGroupToHostGroup'
                'Add-DMmapLunToHost'
                'Add-DMPortGroupToMappingView'
                'Add-DMPortToPortGroup'
                'Get-DMMappingView'
                'Get-DMPortGroup'
                'New-DMMappingView'
                'New-DMPortGroup'
                'Remove-DMHostGroupFromMappingView'
                'Remove-DMLunGroupFromMappingView'
                'Remove-DMmapLunFromHost'
                'Remove-DMMappingView'
                'Remove-DMPortFromPortGroup'
                'Remove-DMPortGroup'
                'Remove-DMPortGroupFromMappingView'
                'Remove-DMunmapLunGroupFromHost'
                'Remove-DMunmapLunGroupFromHostGroup'
                'Rename-DMMappingView'
                'Rename-DMPortGroup'
                'Set-DMMappingView'
                'Set-DMPortGroup'
            )
        }

        Snapshot = @{
            DefaultEnabled = $true
            Description    = 'LUN snapshots, snapshot consistency groups, and HyperCDP schedules.'
            Commands       = @(
                'Add-DMLunToHyperCDPSchedule'
                'Disable-DMHyperCDPSchedule'
                'Enable-DMHyperCDPSchedule'
                'Enable-DMLunSnapshot'
                'Enable-DMSnapshotConsistencyGroup'
                'Get-DMHyperCDPSchedule'
                'Get-DMLunSnapshot'
                'Get-DMSnapshotConsistencyGroup'
                'New-DMHyperCDPSchedule'
                'New-DMLunSnapshot'
                'New-DMLunSnapshotCopy'
                'New-DMSnapshotConsistencyGroup'
                'New-DMSnapshotConsistencyGroupCopy'
                'Remove-DMLunFromHyperCDPSchedule'
                'Remove-DMHyperCDPSchedule'
                'Remove-DMLunSnapShot'
                'Remove-DMSnapshotConsistencyGroup'
                'Resize-DMLunSnapshot'
                'Restart-DMLunSnapshot'
                'Restart-DMSnapshotConsistencyGroup'
                'Restore-DMLunSnapshot'
                'Restore-DMSnapshotConsistencyGroup'
                'Set-DMHyperCDPSchedule'
            )
        }

        Protection = @{
            DefaultEnabled = $true
            Description    = 'Protection groups.'
            Commands       = @(
                'Add-DMLunToProtectionGroup'
                'Get-DMProtectionGroup'
                'New-DMProtectionGroup'
                'Remove-DMLunFromProtectionGroup'
                'Remove-DMProtectionGroup'
                'Rename-DMProtectionGroup'
                'Set-DMProtectionGroup'
            )
        }

        QoS = @{
            DefaultEnabled = $true
            Description    = 'QoS policies and their associations.'
            Commands       = @(
                'Add-DMQosAssociation'
                'Get-DMQosPolicy'
                'New-DMQosPolicy'
                'Remove-DMQosAssociation'
                'Remove-DMQosPolicy'
                'Set-DMQosPolicy'
                'Start-DMQosPolicy'
                'Stop-DMQosPolicy'
            )
        }

        FileSystem = @{
            DefaultEnabled = $true
            Description    = 'File systems, FS snapshots, dTrees, quotas, CIFS/NFS shares & clients, and vStores.'
            Commands       = @(
                'Get-DMFileSystem'
                'Get-DMFileSystemSnapshot'
                'Get-DMnfsFileClient'
                'Get-DMQuota'
                'Get-DMShare'
                'Get-DMvStore'
                'New-DMCifsShare'
                'New-DMdTree'
                'New-DMFileSystem'
                'New-DMFileSystemSnapshot'
                'New-DMnfsClient'
                'New-DMnfsShare'
                'New-DMQuota'
                'Remove-DMCifsShare'
                'Remove-DMDTree'
                'Remove-DMFileSystem'
                'Remove-DMFileSystemSnapshot'
                'Remove-DMNfsClient'
                'Remove-DMNfsShare'
                'Remove-DMQuota'
                'Rename-DMFileSystem'
                'Restore-DMFileSystemSnapshot'
                'Set-DMCifsShare'
                'Set-DMdTree'
                'Set-DMFileSystem'
                'Set-DMnfsClient'
                'Set-DMnfsShare'
                'Set-DMQuota'
            )
        }

        Network = @{
            DefaultEnabled = $true
            Description    = 'ETH/FC/SAS ports, VLANs, LIFs, bonds, failover groups, DNS, and LLDP.'
            Commands       = @(
                'Add-DMFailoverGroupMember'
                'Get-DMdnsServer'
                'Get-DMFailoverGroup'
                'Get-DMFailoverGroupMember'
                'Get-DMLif'
                'Get-DMLLDPWorkingMode'
                'Get-DMPortBond'
                'Get-DMPortETH'
                'Get-DMPortFc'
                'Get-DMPortSAS'
                'Get-DMvLan'
                'New-DMFailoverGroup'
                'New-DMLif'
                'New-DMPortBond'
                'New-DMvLan'
                'Remove-DMFailoverGroup'
                'Remove-DMFailoverGroupMember'
                'Remove-DMLif'
                'Remove-DMPortBond'
                'Remove-DMvLan'
                'Set-DMdnsServer'
                'Set-DMFailoverGroup'
                'Set-DMLif'
                'Set-DMLLDPWorkingMode'
                'Set-DMPortBond'
                'Set-DMvLan'
            )
        }

        Hardware = @{
            DefaultEnabled = $true
            Description    = 'Disks, enclosures, controllers, BBUs, interface modules, and equipment status.'
            Commands       = @(
                'Get-DMbbu'
                'Get-DMcofferDisk'
                'Get-DMController'
                'Get-DMDiskbyLocation'
                'Get-DMDiskByStoragePool'
                'Get-DMdisk'
                'Get-DMEnclosure'
                'Get-DMEquipmentStatus'
                'Get-DMfreeDisk'
                'Get-DMInterfaceModule'
            )
        }

        StoragePool = @{
            DefaultEnabled = $true
            Description    = 'Storage pool getters and rename.'
            Commands       = @(
                'Get-DMstoragePool'
                'Rename-DMstoragePool'
            )
        }

        Performance = @{
            DefaultEnabled = $true
            Description    = 'Performance counters, capacity history, performance monitoring, and report tasks.'
            Commands       = @(
                'Get-DMCapacityHistory'
                'Get-DMControllerPerformance'
                'Get-DMDiskPerformance'
                'Get-DMFileSystemPerformance'
                'Get-DMHostPerformance'
                'Get-DMLunPerformance'
                'Get-DMPerformance'
                'Get-DMPerformanceHistory'
                'Get-DMPerformanceMonitoring'
                'Get-DMPerformanceReportTask'
                'Get-DMPortPerformance'
                'Get-DMStoragePoolPerformance'
                'Get-DMSystemPerformance'
                'Disable-DMPerformanceMonitoring'
                'Enable-DMPerformanceMonitoring'
                'Invoke-DMPerformanceReportTask'
                'New-DMPerformanceReportTask'
                'Remove-DMPerformanceReportTask'
                'Save-DMPerformanceReportFile'
                'Set-DMPerformanceMonitoring'
            )
        }

        SystemManagement = @{
            DefaultEnabled = $true
            Description    = 'Alarms, certificates, local users, roles, SNMP, NTP, syslog, timezone/UTC, and other system administration.'
            Commands       = @(
                'Add-DMSyslogServer'
                'Clear-DMAlarm'
                'Disable-DMLocalUserSession'
                'Get-DMAlarm'
                'Get-DMAlarmHistory'
                'Get-DMAlarmMasking'
                'Get-DMAlarmType'
                'Get-DMCertificate'
                'Get-DMLocalUser'
                'Get-DMNtpServer'
                'Get-DMNtpStatus'
                'Get-DMRole'
                'Get-DMRolePermission'
                'Get-DMSnmpConfig'
                'Get-DMSnmpSecurityPolicy'
                'Get-DMSnmpTrapServer'
                'Get-DMSnmpUsmUser'
                'Get-DMSyslogNotification'
                'Get-DMTimeZone'
                'Get-DMutcTime'
                'Lock-DMLocalUser'
                'New-DMLocalUser'
                'New-DMRole'
                'New-DMSnmpTrapServer'
                'New-DMSnmpUsmUser'
                'Remove-DMLocalUser'
                'Remove-DMRole'
                'Remove-DMSnmpTrapServer'
                'Remove-DMSnmpUsmUser'
                'Remove-DMSyslogServer'
                'Reset-DMLocalUserPassword'
                'Set-DMAlarmMasking'
                'Set-DMLocalUser'
                'Set-DMNtpServer'
                'Set-DMRole'
                'Set-DMSnmpCommunity'
                'Set-DMSnmpConfig'
                'Set-DMSnmpSecurityPolicy'
                'Set-DMSnmpTrapServer'
                'Set-DMSnmpUsmUser'
                'Set-DMSyslogNotification'
                'Set-DMTimeZone'
                'Set-DMutcTime'
                'Test-DMNtpServer'
                'Test-DMSnmpTrapServer'
                'Unlock-DMLocalUser'
            )
        }

    }
}
