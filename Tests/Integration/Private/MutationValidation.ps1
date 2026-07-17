. (Join-Path $PSScriptRoot 'Workflows\Lun.ps1')
. (Join-Path $PSScriptRoot 'Workflows\HyperCDPSchedule.ps1')
. (Join-Path $PSScriptRoot 'Workflows\LunGroup.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Host.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Nas.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Quota.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Mapping.ps1')
. (Join-Path $PSScriptRoot 'Workflows\DirectMapping.ps1')
. (Join-Path $PSScriptRoot 'Workflows\StoragePool.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Protection.ps1')
. (Join-Path $PSScriptRoot 'Workflows\QoS.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Replication.ps1')
. (Join-Path $PSScriptRoot 'Workflows\HyperMetro.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Initiators.ps1')
. (Join-Path $PSScriptRoot 'Workflows\SystemManagement.ps1')
. (Join-Path $PSScriptRoot 'Workflows\FailoverGroup.ps1')
. (Join-Path $PSScriptRoot 'Workflows\SupervisedNetwork.ps1')
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

    # Global and authentication system-management mutators with no test-owned
    # variant (singleton settings, or actions against pre-existing users). Every
    # run skips them deliberately; without this explicit result the coverage
    # fallback in Write-ValidationReport would mislabel them as Blocked during
    # mutating runs. Discrete, test-ownable system-management objects (SNMP trap
    # servers, SNMP USM users, syslog servers, local roles/users) are covered by
    # the config-gated SystemManagement workflow instead.
    $script:systemManagementMutators = @(
        'Set-DMNtpServer', 'Test-DMNtpServer',
        'Set-DMSnmpConfig', 'Set-DMSnmpSecurityPolicy', 'Set-DMSnmpCommunity',
        'Set-DMSyslogNotification',
        'Lock-DMLocalUser', 'Unlock-DMLocalUser', 'Disable-DMLocalUserSession', 'Reset-DMLocalUserPassword',
        'Set-DMTimeZone', 'Set-DMutcTime'
    )
    Add-SkippedResult -Name $script:systemManagementMutators -Status 'SkippedUnsafe' -Reason 'Global system-management mutations (users, roles, SNMP, syslog, NTP, time) are not exercised by the integrity harness unless a dedicated safe workflow exists for them.'

    $script:systemManagementWorkflowCommands = @($script:SystemManagementWorkflowCommandGates.Values | ForEach-Object { $_ })

    # Network mutators with no safe test-owned workflow. Creating, modifying or
    # removing bond ports, VLANs or LIFs touches live physical ports, and the
    # LLDP working mode is a global setting; none of these are exercised by the
    # harness. The failover-group lifecycle (a pure metadata object) is covered
    # by the config-gated FailoverGroup workflow instead.
    # In-place network setters and the global LLDP working mode have no test-owned
    # variant and are never exercised. Create/remove of bonds, VLANs and LIFs is now
    # covered by the operator-supervised network-stack workflow (gated separately
    # below), so those commands are no longer unconditionally SkippedUnsafe here.
    $script:networkUnsafeMutators = @(
        'Set-DMPortBond', 'Set-DMvLan', 'Set-DMLif', 'Set-DMLLDPWorkingMode'
    )
    Add-SkippedResult -Name $script:networkUnsafeMutators -Status 'SkippedUnsafe' -Reason 'In-place network setters (Set-DMPortBond/Set-DMvLan/Set-DMLif) and the global LLDP working mode have no test-owned variant and are not exercised by the integrity harness (see docs/network/safety-and-live-validation.md).'

    $script:failoverGroupWorkflowCommands = @($script:FailoverGroupWorkflowCommandGates.Values | ForEach-Object { $_ })

    # Operator-supervised network-stack workflow gating. Create/remove of bonds,
    # VLANs and LIFs is represented by real Supervised results only when a supervised
    # run is active (-RunSupervisedTests + Network.Enabled + Network.Supervised.Enabled
    # + a stack Allow* gate). Otherwise the commands report NotRequested (switch
    # absent) or NotConfigured (master/Network gate off); when the master gate is on
    # but a stack is off, the workflow itself emits NotConfigured for the uncovered
    # commands. Failover-group commands stay owned by the FailoverGroup workflow above.
    $runMutation = [bool]($RunMutatingTests -and $configuration.AllowMutatingTests)
    $runSupervised = [bool]($RunSupervisedTests -and $configuration.Network -and $configuration.Network.Enabled -and $configuration.Network.Supervised -and $configuration.Network.Supervised.Enabled)
    if (-not $RunSupervisedTests) {
        Add-SkippedResult -Name $script:SupervisedNetworkStackCommands -Status 'NotRequested' -Category 'Supervised' -Reason 'Call the runner with -RunSupervisedTests and enable the Network.Supervised gates in IntegrityValidationConfig.psd1 to run the operator-supervised network-stack workflows.'
    }
    elseif (-not $runSupervised) {
        Add-SkippedResult -Name $script:SupervisedNetworkStackCommands -Status 'NotConfigured' -Category 'Supervised' -Reason 'Set Network.Enabled = $true and Network.Supervised.Enabled = $true (plus a stack Allow* gate) in IntegrityValidationConfig.psd1 to run the supervised network-stack workflows.'
    }

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
            'New-DMQosPolicy', 'Set-DMQosPolicy', 'Stop-DMQosPolicy', 'Start-DMQosPolicy',
            'Add-DMQosAssociation', 'Remove-DMQosAssociation', 'Remove-DMQosPolicy',
            'New-DMSnapshotConsistencyGroup', 'New-DMSnapshotConsistencyGroupCopy',
            'Enable-DMSnapshotConsistencyGroup', 'Restart-DMSnapshotConsistencyGroup',
            'Restore-DMSnapshotConsistencyGroup', 'Remove-DMSnapshotConsistencyGroup',
            'Remove-DMFiberChannelInitiatorFromHost', 'Remove-DMIscsiInitiatorFromHost',
            'Set-DMLun', 'Rename-DMLun', 'Set-DMFileSystem', 'Rename-DMFileSystem',
            'Set-DMHost', 'Rename-DMHost', 'Set-DMHostGroup', 'Rename-DMHostGroup',
            'Set-DMLunGroup', 'Rename-DMLunGroup', 'Set-DMPortGroup', 'Rename-DMPortGroup',
            'Rename-DMstoragePool',
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
        Add-SkippedResult -Name $script:systemManagementWorkflowCommands -Status 'NotRequested' -Reason 'Call the runner with -RunMutatingTests and enable the SystemManagement gates in IntegrityValidationConfig.psd1 to run the test-owned system-management lifecycles.'
        Add-SkippedResult -Name $script:failoverGroupWorkflowCommands -Status 'NotRequested' -Reason 'Call the runner with -RunMutatingTests and enable the Network gates in IntegrityValidationConfig.psd1 to run the test-owned failover-group lifecycle.'
    }
    elseif (-not $configuration.AllowMutatingTests) {
        Add-SkippedResult -Name @('test-owned mutation workflows') -Status 'NotConfigured' -Reason 'Set AllowMutatingTests = $true in IntegrityValidationConfig.psd1 to acknowledge creation and cleanup of test resources.'
    }

    if ($runMutation -or $runSupervised) {
        Enable-DMValidationRequestTrace -Sink $mutationRequests

        if ($runMutation) {
        Test-MutatingConfiguration
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
        # SmartQoS policy names are capped at 31 chars (Set-DMQosPolicy -NewName has
        # [ValidateLength(1,31)]). The 'dm_integrity_<runId>_' prefix already consumes 28,
        # so the rename target uses a compact 'qsr' suffix instead of the descriptive
        # '_renamed' used by objects (LUN, FS, ...) that allow longer names.
        $renamedQosPolicyName = New-TestName -Suffix 'qsr'
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
        # HyperCDP schedule names are capped at 31 characters on live arrays;
        # prefix(12) + '_' + runId(14) + '_' + 'cdp'(3) lands exactly on the cap.
        $hyperCdpScheduleName = New-TestName -Suffix 'cdp'
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
        . $script:StoragePoolMutationWorkflow
        . $script:ProtectionMutationWorkflow
        . $script:QosMutationWorkflow
        . $script:ReplicationMutationWorkflow
        . $script:HyperMetroMutationWorkflow
        . $script:InitiatorsMutationWorkflow
        . $script:SystemManagementMutationWorkflow
        . $script:FailoverGroupMutationWorkflow
        . $script:MutationReadBackWorkflow
        }

        if ($runSupervised) {
            Test-SupervisedConfiguration
            . $script:SupervisedNetworkWorkflow
        }

        Invoke-RegisteredCleanup

        Invoke-MutationStep -Name 'Disconnect-deviceManager' -Action {
            Disconnect-deviceManager -WebSession $session
        }
        $script:sessionDisconnected = $true
    }
}
