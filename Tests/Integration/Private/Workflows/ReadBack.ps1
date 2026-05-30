$script:MutationReadBackWorkflow = {

        if ($owned.Lun.Contains($lunName)) {
            Add-MutationReadVerification -Name 'Get-DMluns:Created' -Action {
                Get-DMluns -WebSession $session | Where-Object Name -EQ $lunName
            } | Out-Null
        }
        if ($owned.LunSnapshot.Contains($snapshotName)) {
            Add-MutationReadVerification -Name 'Get-DMLunSnapshots:Created' -ExpectedType 'OceanstorLunSnapshot' -Action {
                Get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $snapshotName
            } | Out-Null
        }
        if ($owned.LunGroup.Contains($lunGroupName)) {
            Add-MutationReadVerification -Name 'Get-DMlunGroups:Created' -ExpectedType 'OceanStorLunGroup' -Action {
                Get-DMlunGroups -WebSession $session | Where-Object Name -EQ $lunGroupName
            } | Out-Null
        }
        if ($lunGroupContainsLun) {
            Add-MutationReadVerification -Name 'Get-DMlunsbyLunGroup:Association' -Action {
                Get-DMlunsbyLunGroup -WebSession $session -LunGroup $lunGroup[0] | Where-Object Name -EQ $lunName
            } | Out-Null
        }
        if ($owned.Host.Contains($testHostName)) {
            Add-MutationReadVerification -Name 'Get-DMhosts:Created' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhosts -WebSession $session | Where-Object Name -EQ $testHostName
            } | Out-Null
        }
        if ($hostGroupContainsHost) {
            Add-MutationReadVerification -Name 'Get-DMhostsbyHostGroupId:Association' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhostsbyHostGroupId -WebSession $session -HostGroupId $hostGroup[0].Id | Where-Object Name -EQ $testHostName
            } | Out-Null
            Add-MutationReadVerification -Name 'Get-DMhostsbyHostGroupName:Association' -ExpectedType 'OceanStorHost' -Action {
                Get-DMhostsbyHostGroupName -WebSession $session -HostGroupName $hostGroupName | Where-Object Name -EQ $testHostName
            } | Out-Null
        }
        if ($owned.FileSystem.Contains($fileSystemName)) {
            Add-MutationReadVerification -Name 'Get-DMFileSystem:Created' -ExpectedType 'OceanstorFileSystem' -Action {
                Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fileSystemName
            } | Out-Null
        }
        if ($owned.FileSystemSnapshot.Contains($fileSystemSnapshotName)) {
            Add-MutationReadVerification -Name 'Get-DMFileSystemSnapshots:Created' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
                Get-DMFileSystemSnapshots -WebSession $session -FileSystemName $fileSystemName | Where-Object Name -EQ $fileSystemSnapshotName
            } | Out-Null
        }
        if ($owned.NfsShare.Contains($nfsSharePath)) {
            Add-MutationReadVerification -Name 'Get-DMShares:NFS:Created' -ExpectedType 'OceanStorNFSShare' -Action {
                Get-DMShares -WebSession $session -ShareType NFS | Where-Object 'Share Path' -EQ $nfsSharePath
            } | Out-Null
        }
        if ($owned.CifsShare.Contains($cifsShareName)) {
            Add-MutationReadVerification -Name 'Get-DMShares:CIFS:Created' -ExpectedType 'OceanStorCIFSShare' -Action {
                Get-DMShares -WebSession $session -ShareType CIFS | Where-Object Name -EQ $cifsShareName
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
