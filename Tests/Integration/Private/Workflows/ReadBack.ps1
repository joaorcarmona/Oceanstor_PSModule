$script:MutationReadBackWorkflow = {

        if ($owned.Lun.Contains($lunName)) {
            Add-MutationReadVerification -Name 'Get-DMlun:Created' -Action {
                Get-DMlun -WebSession $session | Where-Object Name -EQ $lunName
            } | Out-Null
        }
        if ($owned.LunSnapshot.Contains($snapshotName)) {
            Add-MutationReadVerification -Name 'Get-DMLunSnapshot:Created' -ExpectedType 'OceanstorLunSnapshot' -Action {
                Get-DMLunSnapshot -WebSession $session | Where-Object Name -EQ $snapshotName
            } | Out-Null
        }
        if ($owned.LunGroup.Contains($lunGroupName)) {
            Add-MutationReadVerification -Name 'Get-DMlunGroup:Created' -ExpectedType 'OceanStorLunGroup' -Action {
                Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $lunGroupName
            } | Out-Null
        }
        if ($lunGroupContainsLun) {
            Add-MutationReadVerification -Name 'Get-DMlunbyLunGroup:Association' -Action {
                Get-DMlunbyLunGroup -WebSession $session -LunGroup $lunGroup[0] | Where-Object Name -EQ $lunName
            } | Out-Null
        }
        if ($owned.Host.Contains($testHostName)) {
            Add-MutationReadVerification -Name 'Get-DMhost:Created' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhost -WebSession $session | Where-Object Name -EQ $testHostName
            } | Out-Null
        }
        if ($hostGroupContainsHost) {
            Add-MutationReadVerification -Name 'Get-DMhostbyHostGroupId:Association' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhostbyHostGroupId -WebSession $session -HostGroupId $hostGroup[0].Id | Where-Object Name -EQ $testHostName
            } | Out-Null
            Add-MutationReadVerification -Name 'Get-DMhostbyHostGroupName:Association' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhostbyHostGroupName -WebSession $session -HostGroupName $hostGroupName | Where-Object Name -EQ $testHostName
            } | Out-Null
        }
        if ($owned.FileSystem.Contains($fileSystemName)) {
            Add-MutationReadVerification -Name 'Get-DMFileSystem:Created' -ExpectedType 'OceanstorFileSystem' -Action {
                Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fileSystemName
            } | Out-Null
        }
        if ($owned.FileSystemSnapshot.Contains($fileSystemSnapshotName)) {
            Add-MutationReadVerification -Name 'Get-DMFileSystemSnapshot:Created' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
                Get-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName -SnapshotName $fileSystemSnapshotName
            } | Out-Null
        }
        if ($owned.NfsShare.Contains($nfsSharePath)) {
            Add-MutationReadVerification -Name 'Get-DMShare:NFS:Created' -ExpectedType 'OceanStorNFSShare' -Action {
                Get-DMShare -WebSession $session -ShareType NFS | Where-Object 'Share Path' -EQ $nfsSharePath
            } | Out-Null
        }
        if ($owned.CifsShare.Contains($cifsShareName)) {
            Add-MutationReadVerification -Name 'Get-DMShare:CIFS:Created' -ExpectedType 'OceanStorCIFSShare' -Action {
                Get-DMShare -WebSession $session -ShareType CIFS | Where-Object Name -EQ $cifsShareName
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

}
