# Run read-only validation:
#   ./Invoke-GetterIntegrityValidation.ps1 -Hostname '<array-address>'
#
# Run configured test-owned create/modify/remove validation:
#   ./Invoke-GetterIntegrityValidation.ps1 -Hostname '<array-address>' -RunMutatingTests
@{
    # This file contains no login details. Hostname is supplied to the runner and
    # credentials are requested interactively by connect-deviceManager -Secure.
    #
    # Mutating validation runs only when this is true AND the runner is called
    # with -RunMutatingTests. Every changed or removed storage object must first
    # have been created and registered by that same run.
    AllowMutatingTests = $false

    # Used for all generated storage object names. Keep this short enough that
    # "<prefix>_<yyyyMMddHHmmss>_<suffix>" satisfies array naming limits.
    NamePrefix = 'dm_integrity'

    # Required by LUN and NAS tests. Supply an existing storage pool ID only as
    # a placement target; the runner never modifies or deletes the pool.
    StoragePoolId = ''

    Lun = @{
        Enabled = $false
        CapacityMB = 1024
        AllocationType = 'Thin'

        # Set to 0 to skip Resize-DMLunSnapshot. To test resizing, set a sector
        # value larger than the capacity returned for the generated snapshot.
        ExpandedSnapshotCapacitySectors = 0
    }

    LunGroup = @{
        Enabled = $false
        ApplicationType = 'Other'
    }

    Host = @{
        Enabled = $false
        OperatingSystem = 'Linux'
    }

    Nas = @{
        Enabled = $false
        FileSystemCapacityGB = 1
        EnableDTree = $true
        EnableFileSystemSnapshot = $true
        EnableNfs = $true
        EnableCifs = $false

        # NFS client identity to grant on the export created by this test.
        # Example: '192.0.2.50' or 'validation.example.test'.
        NfsClientName = ''
    }

    Mapping = @{
        Enabled = $false
    }

    Initiators = @{
        Enabled = $false

        # Supply only unused/free identities that may be created and deleted by
        # the test. Leave an identity blank to skip that protocol.
        FibreChannelWWN = ''
        IscsiIdentifier = ''
        NvmeNqn = ''
    }
}
