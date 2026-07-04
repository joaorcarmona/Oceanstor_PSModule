. (Join-Path $PSScriptRoot 'Workflows\Lun.ps1')
. (Join-Path $PSScriptRoot 'Workflows\LunGroup.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Host.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Nas.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Mapping.ps1')
. (Join-Path $PSScriptRoot 'Workflows\DirectMapping.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Protection.ps1')
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

    if (-not $RunMutatingTests) {
        Add-SkippedResult -Name @(
            'New-DMLun', 'New-DMLunSnapshot', 'New-DMLunSnapshotCopy', 'Enable-DMLunSnapshot',
            'Restart-DMLunSnapshot', 'Resize-DMLunSnapshot', 'Restore-DMLunSnapshot', 'Remove-DMLunSnapShot',
            'Remove-DMLun', 'New-DMFileSystem', 'New-DMdTree', 'Remove-DMDTree',
            'New-DMFileSystemSnapshot', 'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot',
            'New-DMnfsShare', 'New-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare',
            'New-DMCifsShare', 'Remove-DMCifsShare', 'Remove-DMFileSystem', 'New-DMPortGroup', 'New-DMMappingView',
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
            'New-DMSnapshotConsistencyGroup', 'New-DMSnapshotConsistencyGroupCopy',
            'Enable-DMSnapshotConsistencyGroup', 'Restart-DMSnapshotConsistencyGroup',
            'Restore-DMSnapshotConsistencyGroup', 'Remove-DMSnapshotConsistencyGroup',
            'Remove-DMFiberChannelInitiatorFromHost', 'Remove-DMIscsiInitiatorFromHost',
            'Set-DMLun', 'Rename-DMLun', 'Set-DMFileSystem', 'Rename-DMFileSystem',
            'Set-DMHost', 'Rename-DMHost', 'Set-DMHostGroup', 'Rename-DMHostGroup',
            'Set-DMLunGroup', 'Rename-DMLunGroup', 'Set-DMPortGroup', 'Rename-DMPortGroup',
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
        $consistencyGroupName = New-TestName -Suffix 'cgsnap'
        $consistencyCopyName = New-TestName -Suffix 'cgcopy'
        $testHostName = New-TestName -Suffix 'host'
        $renamedHostName = New-TestName -Suffix 'host_renamed'
        $hostGroupName = New-TestName -Suffix 'hostgroup'
        $renamedHostGroupName = New-TestName -Suffix 'hostgroup_renamed'
        $mapLunName = New-TestName -Suffix 'maplun'
        $mapHostName = New-TestName -Suffix 'maphost'
        $mapHostGroupName = New-TestName -Suffix 'maphostgroup'
        $lunGroupContainsLun = $false
        $hostGroupContainsHost = $false
        $mappingContainsHostGroup = $false
        $mappingContainsLunGroup = $false
        $mappingContainsPortGroup = $false

        . $script:LunMutationWorkflow
        . $script:LunGroupMutationWorkflow
        . $script:HostMutationWorkflow
        . $script:NasMutationWorkflow
        . $script:MappingMutationWorkflow
        . $script:DirectMappingMutationWorkflow
        . $script:ProtectionMutationWorkflow
        . $script:InitiatorsMutationWorkflow
        . $script:MutationReadBackWorkflow

        Invoke-RegisteredCleanup

        Invoke-MutationStep -Name 'Disconnect-deviceManager' -Action {
            Disconnect-deviceManager -WebSession $session
        }
        $script:sessionDisconnected = $true
    }
}
