. (Join-Path $PSScriptRoot 'Workflows\Lun.ps1')
. (Join-Path $PSScriptRoot 'Workflows\LunGroup.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Host.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Nas.ps1')
. (Join-Path $PSScriptRoot 'Workflows\Mapping.ps1')
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
        'Export-DMStorageToExcel'
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
        Add-SkippedResult -Name @('test-owned mutation workflows') -Status 'NotConfigured' -Reason 'Set AllowMutatingTests = $true in IntegrityValidationConfig.psd1 to acknowledge creation and cleanup of test resources.'
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

        . $script:LunMutationWorkflow
        . $script:LunGroupMutationWorkflow
        . $script:HostMutationWorkflow
        . $script:NasMutationWorkflow
        . $script:MappingMutationWorkflow
        . $script:ProtectionMutationWorkflow
        . $script:InitiatorsMutationWorkflow
        . $script:MutationReadBackWorkflow

        Invoke-RegisteredCleanup
    }
}
