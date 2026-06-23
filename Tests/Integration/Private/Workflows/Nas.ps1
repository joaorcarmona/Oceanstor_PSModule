$script:NasMutationWorkflow = {
        if ($configuration.Nas.Enabled) {
            $fileSystem = @(Invoke-MutationStep -Name 'New-DMFileSystem' -ExpectedType 'OceanstorFileSystem' -Action {
                if (@(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fileSystemName).Count -gt 0) {
                    throw "A file system named '$fileSystemName' already exists; refusing to claim it as test-owned."
                }
                New-DMFileSystem -WebSession $session -FileSystemName $fileSystemName `
                    -StoragePoolID $configuration.StoragePoolId -Capacity $configuration.Nas.FileSystemCapacityGB `
                    -Description "Integrity validation run $runId"
            })
            if ($fileSystem.Count -gt 0 -and $fileSystem[0].Name -eq $fileSystemName) {
                Register-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                Register-CleanupAction -Name 'Remove-DMFileSystem' -Action {
                    Invoke-OwnedRemoval -Name 'Remove-DMFileSystem' -Kind FileSystem -Identity $fileSystemName -Action {
                        Remove-DMFileSystem -WebSession $session -FileSystemName $fileSystemName -Force -Confirm:$false
                    }
                }
            }

            if ($owned.FileSystem.Contains($fileSystemName)) {
                Invoke-MutationStep -Name 'Set-DMFileSystem' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    Set-DMFileSystem -WebSession $session -FileSystemName $fileSystemName `
                        -Description "Integrity validation updated $runId" -Confirm:$false
                } | Out-Null
                $renameResult = @(Invoke-MutationStep -Name 'Rename-DMFileSystem' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    if (@(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $renamedFileSystemName).Count -gt 0) {
                        throw "A file system named '$renamedFileSystemName' already exists; refusing to overwrite it."
                    }
                    Rename-DMFileSystem -WebSession $session -FileSystemName $fileSystemName `
                        -NewName $renamedFileSystemName -Confirm:$false
                })
                if ($renameResult.Count -gt 0) {
                    Update-TestOwnedResourceIdentity -Kind FileSystem -OldIdentity $fileSystemName -NewIdentity $renamedFileSystemName
                    $fileSystemName = $renamedFileSystemName
                    $nfsSharePath = "/$fileSystemName/"
                    Add-MutationReadVerification -Name 'Rename-DMFileSystem:ReadBack' -ExpectedType 'OceanstorFileSystem' -Action {
                        Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fileSystemName
                    } | Out-Null
                }
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableFileSystemSnapshot) {
                $fsSnapshot = @(Invoke-MutationStep -Name 'New-DMFileSystemSnapshot' -ExpectedType 'OceanstorFileSystemSnapshot' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    New-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName `
                        -SnapshotName $fileSystemSnapshotName -Description "Integrity validation run $runId"
                })
                if ($fsSnapshot.Count -gt 0 -and $fsSnapshot[0].Name -eq $fileSystemSnapshotName) {
                    Register-TestOwnedResource -Kind FileSystemSnapshot -Identity $fileSystemSnapshotName
                    Register-CleanupAction -Name 'Remove-DMFileSystemSnapshot' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMFileSystemSnapshot' -Kind FileSystemSnapshot -Identity $fileSystemSnapshotName -Action {
                            Remove-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName `
                                -SnapshotName $fileSystemSnapshotName -Confirm:$false
                        }
                    }
                    Invoke-MutationStep -Name 'Restore-DMFileSystemSnapshot' -Action {
                        Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                        Assert-TestOwnedResource -Kind FileSystemSnapshot -Identity $fileSystemSnapshotName
                        Restore-DMFileSystemSnapshot -WebSession $session -FileSystemName $fileSystemName `
                            -SnapshotName $fileSystemSnapshotName -Confirm:$false
                    } | Out-Null
                }
            }
            elseif (-not $configuration.Nas.EnableFileSystemSnapshot) {
                Add-SkippedResult -Name @('New-DMFileSystemSnapshot', 'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot') `
                    -Status 'NotConfigured' -Reason 'Set Nas.EnableFileSystemSnapshot = $true to run the file-system snapshot workflow.'
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableDTree) {
                $dTree = @(Invoke-MutationStep -Name 'New-DMdTree' -ExpectedType 'OceanStorDtree' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    New-DMdTree -WebSession $session -FileSystemId $fileSystem[0].Id -DTreeName $dTreeName
                })
                if ($dTree.Count -gt 0) {
                    Register-TestOwnedResource -Kind DTree -Identity $dTreeName
                    Register-CleanupAction -Name 'Remove-DMDTree' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMDTree' -Kind DTree -Identity $dTreeName -Action {
                            Remove-DMDTree -WebSession $session -FileSystemName $fileSystemName -DTreeName $dTreeName -Confirm:$false
                        }
                    }
                }
            }
            elseif (-not $configuration.Nas.EnableDTree) {
                Add-SkippedResult -Name @('New-DMdTree', 'Remove-DMDTree') -Status 'NotConfigured' -Reason 'Set Nas.EnableDTree = $true to run the dTree workflow.'
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableNfs) {
                $nfsShare = @(Invoke-MutationStep -Name 'New-DMnfsShare' -ExpectedType 'OceanStorNFSShare' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    if (@(Get-DMShare -WebSession $session -ShareType NFS | Where-Object 'Share Path' -EQ $nfsSharePath).Count -gt 0) {
                        throw "An NFS share using '$nfsSharePath' already exists; refusing to claim it as test-owned."
                    }
                    New-DMnfsShare -WebSession $session -SharePath $nfsSharePath -FileSystemId $fileSystem[0].Id
                })
                if ($nfsShare.Count -gt 0 -and $nfsShare[0].'Share Path' -eq $nfsSharePath) {
                    Register-TestOwnedResource -Kind NfsShare -Identity $nfsSharePath
                    Register-CleanupAction -Name 'Remove-DMNfsShare' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMNfsShare' -Kind NfsShare -Identity $nfsSharePath -Action {
                            Remove-DMNfsShare -WebSession $session -SharePath $nfsSharePath -Confirm:$false
                        }
                    }
                    $nfsClient = @(Invoke-MutationStep -Name 'New-DMnfsClient' -Action {
                        Assert-TestOwnedResource -Kind NfsShare -Identity $nfsSharePath
                        if (@(Get-DMnfsFileClient -WebSession $session | Where-Object Name -EQ $configuration.Nas.NfsClientName).Count -gt 0) {
                            throw "An NFS client named '$($configuration.Nas.NfsClientName)' already exists; its removal could not be safely disambiguated."
                        }
                        New-DMnfsClient -WebSession $session -ClientName $configuration.Nas.NfsClientName `
                            -ShareId $nfsShare[0].Id
                    })
                    if ($nfsClient.Count -gt 0) {
                        Register-TestOwnedResource -Kind NfsClient -Identity $configuration.Nas.NfsClientName
                        Register-CleanupAction -Name 'Remove-DMNfsClient' -Action {
                            Invoke-OwnedRemoval -Name 'Remove-DMNfsClient' -Kind NfsClient -Identity $configuration.Nas.NfsClientName -Action {
                                Remove-DMNfsClient -WebSession $session -ClientName $configuration.Nas.NfsClientName -Confirm:$false
                            }
                        }
                    }
                }
            }
            elseif (-not $configuration.Nas.EnableNfs) {
                Add-SkippedResult -Name @('New-DMnfsShare', 'New-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare') `
                    -Status 'NotConfigured' -Reason 'Set Nas.EnableNfs = $true and provide Nas.NfsClientName to run NFS validation.'
            }

            if ($owned.FileSystem.Contains($fileSystemName) -and $configuration.Nas.EnableCifs) {
                $cifsShare = @(Invoke-MutationStep -Name 'New-DMCifsShare' -ExpectedType 'OceanStorCIFSShare' -Action {
                    Assert-TestOwnedResource -Kind FileSystem -Identity $fileSystemName
                    if (@(Get-DMShare -WebSession $session -ShareType CIFS | Where-Object Name -EQ $cifsShareName).Count -gt 0) {
                        throw "A CIFS share named '$cifsShareName' already exists; refusing to claim it as test-owned."
                    }
                    New-DMCifsShare -WebSession $session -ShareName $cifsShareName -FileSystemName $fileSystemName `
                        -Description "Integrity validation run $runId"
                })
                if ($cifsShare.Count -gt 0 -and $cifsShare[0].Name -eq $cifsShareName) {
                    Register-TestOwnedResource -Kind CifsShare -Identity $cifsShareName
                    Register-CleanupAction -Name 'Remove-DMCifsShare' -Action {
                        Invoke-OwnedRemoval -Name 'Remove-DMCifsShare' -Kind CifsShare -Identity $cifsShareName -Action {
                            Remove-DMCifsShare -WebSession $session -ShareName $cifsShareName -Confirm:$false
                        }
                    }
                }
            }
            elseif (-not $configuration.Nas.EnableCifs) {
                Add-SkippedResult -Name @('New-DMCifsShare', 'Remove-DMCifsShare') -Status 'NotConfigured' -Reason 'Set Nas.EnableCifs = $true to validate a CIFS share below the test-owned file system.'
            }
        }
        else {
            Add-SkippedResult -Name @(
                'New-DMFileSystem', 'Set-DMFileSystem', 'Rename-DMFileSystem', 'New-DMdTree', 'Remove-DMDTree', 'New-DMFileSystemSnapshot',
                'Restore-DMFileSystemSnapshot', 'Remove-DMFileSystemSnapshot', 'New-DMnfsShare',
                'New-DMnfsClient', 'Remove-DMNfsClient', 'Remove-DMNfsShare', 'New-DMCifsShare',
                'Remove-DMCifsShare', 'Remove-DMFileSystem'
            ) -Status 'NotConfigured' -Reason 'Set Nas.Enabled = $true and provide StoragePoolId to run the test-owned NAS workflow.'
        }

}
