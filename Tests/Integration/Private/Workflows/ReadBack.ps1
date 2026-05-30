$script:MutationReadBackWorkflow = {

        if ($owned.Lun.Contains($lunName)) {
            Add-MutationReadVerification -Name 'get-DMluns:Created' -Action {
                get-DMluns -WebSession $session | Where-Object Name -EQ $lunName
            } | Out-Null
        }
        if ($owned.LunSnapshot.Contains($snapshotName)) {
            Add-MutationReadVerification -Name 'get-DMLunSnapshots:Created' -ExpectedType 'OceanstorLunSnapshot' -Action {
                get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $snapshotName
            } | Out-Null
        }
        if ($owned.LunGroup.Contains($lunGroupName)) {
            Add-MutationReadVerification -Name 'get-DMlunGroups:Created' -ExpectedType 'OceanStorLunGroup' -Action {
                get-DMlunGroups -WebSession $session | Where-Object Name -EQ $lunGroupName
            } | Out-Null
        }
        if ($lunGroupContainsLun) {
            Add-MutationReadVerification -Name 'get-DMlunsbyLunGroup:Association' -Action {
                get-DMlunsbyLunGroup -WebSession $session -LunGroup $lunGroup[0] | Where-Object Name -EQ $lunName
            } | Out-Null
        }
        if ($owned.Host.Contains($testHostName)) {
            Add-MutationReadVerification -Name 'get-DMhosts:Created' -ExpectedType 'OceanStorHost' -Action {
                get-DMhosts -WebSession $session | Where-Object Name -EQ $testHostName
            } | Out-Null
        }
        if ($hostGroupContainsHost) {
            Add-MutationReadVerification -Name 'get-DMhostsbyHostGroupId:Association' -ExpectedType 'OceanStorHost' -Action {
                get-DMhostsbyHostGroupId -WebSession $session -HostGroupId $hostGroup[0].Id | Where-Object Name -EQ $testHostName
            } | Out-Null
            Add-MutationReadVerification -Name 'get-DMhostsbyHostGroupName:Association' -ExpectedType 'OceanStorHost' -Action {
                get-DMhostsbyHostGroupName -WebSession $session -HostGroupName $hostGroupName | Where-Object Name -EQ $testHostName
            } | Out-Null
        }
        if ($owned.FileSystem.Contains($fileSystemName)) {
            Add-MutationReadVerification -Name 'get-DMFileSystem:Created' -ExpectedType 'OceanstorFileSystem' -Action {
                get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fileSystemName
            } | Out-Null
        }
        if ($owned.FileSystemSnapshot.Contains($fileSystemSnapshotName)) {
            Add-MutationReadVerification -Name 'Get-DMFileSystemSnapshots:Created' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
                Get-DMFileSystemSnapshots -WebSession $session -FileSystemName $fileSystemName | Where-Object Name -EQ $fileSystemSnapshotName
            } | Out-Null
        }
        if ($owned.NfsShare.Contains($nfsSharePath)) {
            Add-MutationReadVerification -Name 'get-DMShares:NFS:Created' -ExpectedType 'OceanStorNFSShare' -Action {
                get-DMShares -WebSession $session -ShareType NFS | Where-Object 'Share Path' -EQ $nfsSharePath
            } | Out-Null
        }
        if ($owned.CifsShare.Contains($cifsShareName)) {
            Add-MutationReadVerification -Name 'get-DMShares:CIFS:Created' -ExpectedType 'OceanStorCIFSShare' -Action {
                get-DMShares -WebSession $session -ShareType CIFS | Where-Object Name -EQ $cifsShareName
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
