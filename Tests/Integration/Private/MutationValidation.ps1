. (Join-Path $PSScriptRoot 'Workflows\Lun.ps1')
. (Join-Path $PSScriptRoot 'Workflows\HyperCDPSchedule.ps1')
. (Join-Path $PSScriptRoot 'Workflows\LunGroup.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Host.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Nas.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Quota.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Mapping.ps1')
. (Join-Path $PSScriptRoot 'Workflows\DirectMapping.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Protection.ps1')
. (Join-Path $PSScriptRoot 'Workflows\QoS.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Replication.ps1')
. (Join-Path $PSScriptRoot 'Workflows\HyperMetro.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Initiators.ps1')
. (Join-Path $PSScriptRoot 'Workflows\ReadBack.ps1')

function Invoke-MutationValidation {
    $script:excludedCommands = @(
        'Add-DMPortToPortGroup',
        'Remove-DMPortFromPortGroup',
        'Remove-DMNvmeInitiatorFromHost',
        'Set-DMdnsServer',
        'Export-DeviceManager',
        'Export-DMInventory',
        'Export-DMStorageToExcel',
        'Get-DMhostbyFilter',
        'Get-DMhostbyHostGroup',
        'Get-DMhostbyId',
        'Get-DMhostbyName',
        'Get-DMLunbyFilter',
        'Get-DMlunbyLunGroup',
        'Get-DMlunByWWN',
        'Get-DMlunByName',
        'Get-DMDiskByStoragePool',
        'Get-DMcofferDisk',
        'Get-DMDiskbyLocation',
        'Get-DMfreeDisk'
    )

    # Global, authentication, and alerting system-management mutators. No safe
    # test-owned mutation workflow exists for these yet, so every run skips them
    # deliberately; without this explicit result the coverage fallback in
    # Write-ValidationReport would mislabel them as Blocked during mutating runs.
    $script:systemManagementMutators = @(
        'Set-DMNtpServer', 'Test-DMNtpServer',
        'New-DMSnmpTrapServer', 'Set-DMSnmpTrapServer', 'Remove-DMSnmpTrapServer', 'Test-DMSnmpTrapServer',
        'Set-DMSnmpConfig', 'Set-DMSnmpSecurityPolicy', 'Set-DMSnmpCommunity',
        'New-DMSnmpUsmUser', 'Set-DMSnmpUsmUser', 'Remove-DMSnmpUsmUser',
        'Set-DMSyslogNotification', 'Add-DMSyslogServer', 'Remove-DMSyslogServer',
        'New-DMLocalUser', 'Set-DMLocalUser', 'Remove-DMLocalUser',
        'Lock-DMLocalUser', 'Unlock-DMLocalUser', 'Disable-DMLocalUserSession', 'Reset-DMLocalUserPassword',
        'New-DMRole', 'Set-DMRole', 'Remove-DMRole',
        'Set-DMTimeZone', 'Set-DMutcTime'
    )
    Add-SkippedResult -Name $script:systemManagementMutators -Status 'SkippedUnsafe' -Reason 'Global system-management mutations (users, roles, SNMP, syslog, NTP, time) are not exercised by the integrity harness unless a dedicated safe workflow exists for them.'

    if (-not $RunMutatingTests) {
        Add-SkippedResult -Name @(
            'New-DMLun', 'New-DMLunSnapshot', 'New-DMLunSnapshotCopy', 'Enable-DMLunSnapshot',
            'Restart-DMLunSnapshot', 'Resize-DMLunSnapshot', 'Restore-DMLunSnapshot', 'Remove-DMLunSnapShot',
            'New-DMHyperCDPSchedule', 'Set-DMHyperCDPSchedule', 'Add-DMLunToHyperCDPSchedule',
            'Remove-DMLunFromHyperCDPSchedule', 'Enable-DMHyperCDPSchedule', 'Disable-DMHyperCDPSchedule',
            'Remove-DMHyperCDPSchedule',
            'Remove-DMLun', 'New-DMFileSystem', 'New-DMdTree', 'Set-DMdTree', 'Remove-DMDTree',
            'New-DMFileSystemSnapshot', 'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot',
            'New-DMnfsShare', 'Set-DMnfsShare', 'New-DMnfsClient', 'Set-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare',
            'New-DMCifsShare', 'Set-DMCifsShare', 'Remove-DMCifsShare', 'Remove-DMFileSystem',
            'Get-DMQuota', 'New-DMQuota', 'Set-DMQuota', 'Remove-DMQuota', 'New-DMPortGroup', 'New-DMMappingView',
            'Add-DMPortGroupToMappingView', 'Remove-DMPortGroupFromMappingView',
            'Remove-DMMappingView', 'Remove-DMPortGroup', 'New-DMFiberChannelInitiator',
            'Remove-DMFiberChannelInitiator', 'New-DMIscsiInitiator', 'Remove-DMIscsiInitiator',
            'New-DMNvmeInitiator', 'Remove-DMNvmeInitiator',
            'New-DMHost', 'New-DMHostGroup', 'Add-DMHostToHostGroup', 'Remove-DMHostFromHostGroup',
            'Remove-DMHost', 'Remove-DMHostGroup', 'New-DMLunGroup', 'New-DMLun:PipelineBatch',
            'Set-DMLun:PipelineBatch', 'Add-DMLunToLunGroup', 'Add-DMLunToLunGroup:PipelineBatch',
            'Remove-DMLunFromLunGroup', 'Remove-DMLunFromLunGroup:PipelineBatch',
            'Remove-DMLun:PipelineBatchContinueOnError', 'Remove-DMLunGroup', 'Add-DMHostGroupToMappingView',
            'Remove-DMHostGroupFromMappingView', 'Add-DMLunGroupToMappingView',
            'Remove-DMLunGroupFromMappingView', 'Add-DMmapLunToHost', 'Remove-DMmapLunFromHost',
            'Add-DMmapLunGroupToHost', 'Remove-DMunmapLunGroupFromHost',
            'Add-DMmapLunGroupToHostGroup', 'Remove-DMunmapLunGroupFromHostGroup',
            'New-DMProtectionGroup', 'Remove-DMProtectionGroup', 'Set-DMProtectionGroup', 'Rename-DMProtectionGroup',
            'Add-DMLunToProtectionGroup', 'Remove-DMLunFromProtectionGroup',
            'New-DMQosPolicy', 'Set-DMQosPolicy', 'Disable-DMQosPolicy', 'Enable-DMQosPolicy',
            'Add-DMQosAssociation', 'Remove-DMQosAssociation', 'Remove-DMQosPolicy',
            'New-DMSnapshotConsistencyGroup', 'New-DMSnapshotConsistencyGroupCopy',
            'Enable-DMSnapshotConsistencyGroup', 'Restart-DMSnapshotConsistencyGroup',
            'Restore-DMSnapshotConsistencyGroup', 'Remove-DMSnapshotConsistencyGroup',
            'Remove-DMFiberChannelInitiatorFromHost', 'Remove-DMIscsiInitiatorFromHost',
            'Set-DMLun', 'Rename-DMLun', 'Set-DMFileSystem', 'Rename-DMFileSystem',
            'Set-DMHost', 'Rename-DMHost', 'Set-DMHostGroup', 'Rename-DMHostGroup',
            'Set-DMLunGroup', 'Rename-DMLunGroup', 'Set-DMPortGroup', 'Rename-DMPortGroup',
            'Get-DMRemoteDevice', 'Get-DMRemoteLun',
            'New-DMReplicationPair', 'Get-DMReplicationPair', 'Set-DMReplicationPair',
            'Sync-DMReplicationPair', 'Split-DMReplicationPair', 'Switch-DMReplicationPair',
            'Enable-DMReplicationPairSecondaryProtection', 'Disable-DMReplicationPairSecondaryProtection',
            'Remove-DMReplicationPair',
            'New-DMReplicationConsistencyGroup', 'Get-DMReplicationConsistencyGroup',
            'Set-DMReplicationConsistencyGroup', 'Add-DMReplicationPairToConsistencyGroup',
            'Remove-DMReplicationPairFromConsistencyGroup', 'Sync-DMReplicationConsistencyGroup',
            'Split-DMReplicationConsistencyGroup', 'Switch-DMReplicationConsistencyGroup',
            'Remove-DMReplicationConsistencyGroup',
            'Get-DMHyperMetroDomain', 'Get-DMHyperMetroPair', 'New-DMHyperMetroPair',
            'Set-DMHyperMetroPair', 'Sync-DMHyperMetroPair', 'Suspend-DMHyperMetroPair',
            'Start-DMHyperMetroPair', 'Switch-DMHyperMetroPairPriority',
            'Remove-DMHyperMetroPair',
            'New-DMHyperMetroConsistencyGroup', 'Get-DMHyperMetroConsistencyGroup',
            'Set-DMHyperMetroConsistencyGroup', 'Add-DMHyperMetroPairToConsistencyGroup',
            'Remove-DMHyperMetroPairFromConsistencyGroup', 'Sync-DMHyperMetroConsistencyGroup',
            'Suspend-DMHyperMetroConsistencyGroup', 'Start-DMHyperMetroConsistencyGroup',
            'Switch-DMHyperMetroConsistencyGroup', 'Remove-DMHyperMetroConsistencyGroup',
            'Disconnect-deviceManager'
        ) -Status 'NotRequested' -Reason 'Call the runner with -RunMutatingTests and enable the desired section in IntegrityValidationConfig.psd1.'
    }
    elseif (-not $configuration.AllowMutatingTests) {
        Add-SkippedResult -Name @('test-owned mutation workflows') -Status 'NotConfigured' -Reason 'Set AllowMutatingTests = $true in IntegrityValidationConfig.psd1 to acknowledge creation and cleanup of test resources.'
    }
    else {
        Test-MutatingConfiguration
        Enable-DMValidationRequestTrace -Sink $mutationRequests
        $lunName = New-TestName -Suffix 'lun'
        $renamedLunName = New-TestName -Suffix 'lun_renamed'
        $snapshotName = New-TestName -Suffix 'snap'
        $snapshotCopyName = New-TestName -Suffix 'snapcopy'
        $fileSystemName = New-TestName -Suffix 'fs'
        $renamedFileSystemName = New-TestName -Suffix 'fs_renamed'
        $fileSystemSnapshotName = New-TestName -Suffix 'fssnap'
        $dTreeName = New-TestName -Suffix 'dtree'
        $cifsShareName = New-TestName -Suffix 'cifs'
        $nfsSharePath = "/$fileSystemName/"
        $mappingViewName = New-TestName -Suffix 'map'
        $portGroupName = New-TestName -Suffix 'ports'
        $renamedPortGroupName = New-TestName -Suffix 'ports_renamed'
        $lunGroupName = New-TestName -Suffix 'lungroup'
        $renamedLunGroupName = New-TestName -Suffix 'lungroup_renamed'
        $protectionGroupName = New-TestName -Suffix 'protect'
        $renamedProtectionGroupName = New-TestName -Suffix 'protect_renamed'
        $lunProtectionGroupName = New-TestName -Suffix 'protect_luntype'
        $protectionLunName = New-TestName -Suffix 'protect_lun'
        $qosPolicyName = New-TestName -Suffix 'qos'
        $renamedQosPolicyName = New-TestName -Suffix 'qos_renamed'
        $consistencyGroupName = New-TestName -Suffix 'cgsnap'
        $consistencyCopyName = New-TestName -Suffix 'cgcopy'
        $replicationPairName = New-TestName -Suffix 'rpair'
        $replicationGroupName = New-TestName -Suffix 'rcg'
        $hyperMetroGroupName = New-TestName -Suffix 'hmcg'
        $testHostName = New-TestName -Suffix 'host'
        $renamedHostName = New-TestName -Suffix 'host_renamed'
        $hostGroupName = New-TestName -Suffix 'hostgroup'
        $renamedHostGroupName = New-TestName -Suffix 'hostgroup_renamed'
        $mapLunName = New-TestName -Suffix 'maplun'
        $mapHostName = New-TestName -Suffix 'maphost'
        $mapHostGroupName = New-TestName -Suffix 'maphostgroup'
        $hyperCdpScheduleName = New-TestName -Suffix 'hypercdp'
        $hyperCdpScheduleId = $null
        $lunGroupContainsLun = $false
        $hyperCdpScheduleContainsLun = $false
        $hostGroupContainsHost = $false
        $mappingContainsHostGroup = $false
        $mappingContainsLunGroup = $false
        $mappingContainsPortGroup = $false

        . $script:LunMutationWorkflow
        . $script:HyperCDPScheduleMutationWorkflow
        . $script:LunGroupMutationWorkflow
        . $script:HostMutationWorkflow
        . $script:NasMutationWorkflow
        . $script:QuotaMutationWorkflow
        . $script:MappingMutationWorkflow
        . $script:DirectMappingMutationWorkflow
        . $script:ProtectionMutationWorkflow
        . $script:QosMutationWorkflow
        . $script:ReplicationMutationWorkflow
        . $script:HyperMetroMutationWorkflow
        . $script:InitiatorsMutationWorkflow
        . $script:MutationReadBackWorkflow

        Invoke-RegisteredCleanup

        Invoke-MutationStep -Name 'Disconnect-deviceManager' -Action {
            Disconnect-deviceManager -WebSession $session
        }
        $script:sessionDisconnected = $true
    }
}
