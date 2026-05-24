# Run read-only validation:
#   ./Invoke-GetterIntegrityValidation.ps1 -Hostname '<array-address>'
#
# Run configured test-owned create/modify/remove validation:
#   ./Invoke-GetterIntegrityValidation.ps1 -Hostname '<array-address>' -RunMutatingTests
#
# Show a persistent line for each completed check in addition to live progress:
#   ./Invoke-GetterIntegrityValidation.ps1 -Hostname '<array-address>' -RunMutatingTests -ShowTestExecution
#
# Hide the interactive progress display with -NoProgress when redirecting output.
#
# Mutation runs write REST request/response diagnostics to
#   ./mutation-trace-last-result.json
# Override the output location with -MutationLogPath when retaining multiple runs.
@{
    # This file contains no login details. Hostname is supplied to the runner and
    # credentials are requested interactively by connect-deviceManager -Secure.
    #
    # Mutating validation runs only when this is true AND the runner is called
    # with -RunMutatingTests. Every changed or removed storage object must first
    # have been created and registered by that same run.
    AllowMutatingTests = $true

    # Used for all generated storage object names. Keep this short enough that
    # "<prefix>_<yyyyMMddHHmmss>_<suffix>" satisfies array naming limits.
    NamePrefix = 'dm_integrity'

    # Required by LUN and NAS tests. Supply an existing storage pool ID only as
    # a placement target; the runner never modifies or deletes the pool.
    StoragePoolId = '0'

    Lun = @{
        Enabled = $true
        CapacityMB = 1024
        AllocationType = 'Thin'

        # Leave as 0 to automatically expand the generated snapshot by 2048
        # sectors, or set a larger explicit sector capacity for that test.
        ExpandedSnapshotCapacitySectors = 0
    }

    LunGroup = @{
        Enabled = $true
        ApplicationType = 'Other'
    }

    Protection = @{
        # Requires Lun.Enabled and LunGroup.Enabled. Snapshot consistency
        # rollback targets only the LUN created during this test run.
        Enabled = $true
    }

    Host = @{
        Enabled = $true
        OperatingSystem = 'Linux'
    }

    Nas = @{
        Enabled = $true
        FileSystemCapacityGB = 1
        EnableDTree = $true
        EnableFileSystemSnapshot = $true
        EnableNfs = $true
        EnableCifs = $true

        # NFS client identity to grant on the export created by this test.
        # Example: '192.0.2.50' or 'validation.example.test'.
        NfsClientName = '192.0.2.50'
    }

    Mapping = @{
        Enabled = $true
    }

    Initiators = @{
        Enabled = $true

        # Supply only unused/free identities that may be created and deleted by
        # the test. Enable Host to also test FC and iSCSI detachment from the
        # generated host. Leave an identity blank to skip that protocol.
        FibreChannelWWN = '500025B511111111'
        IscsiIdentifier = 'iqn.2003-01.com.example'
        NvmeNqn = 'nqn.2014-08.org.nvmexpress:uuid:123e4567-e89b-12d3-a456-426614174000'
    }
}
