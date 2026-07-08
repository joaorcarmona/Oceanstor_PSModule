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
# Every run writes a machine-readable report to ./getter-integrity-last-result.json
# and a human-readable Markdown summary to ./getter-integrity-last-result.md
# (override with -ReportPath / -MarkdownReportPath).
#
# Mutation runs write REST request/response diagnostics to
#   ./mutation-trace-last-result.json
# Override the output location with -MutationLogPath when retaining multiple runs.
@{
    # This file contains no login details. Hostname is supplied to the runner and
    # credentials are requested interactively by Connect-deviceManager -Secure.
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

        # Leave as 0 to automatically expand the test-owned LUN by 1024 MB
        # over CapacityMB, or set a larger explicit target capacity in MB.
        ExpandedCapacityMB = 0
    }

    LunGroup = @{
        Enabled = $true
        ApplicationType = 'Other'

        # Expensive regression coverage for multi-LUN pipeline handling. This
        # creates three extra LUNs and can add several minutes on arrays where
        # LUN create/remove operations are slow. You can also enable this for a
        # single run with Invoke-GetterIntegrityValidation.ps1 -RunPipelineBatchCoverage.
        EnablePipelineBatchCoverage = $false
    }

    HyperCDPSchedule = @{
        # Non-secure block HyperCDP schedule validation. The workflow creates a
        # disabled schedule, associates the test-owned LUN, removes the
        # association, toggles the schedule, and deletes it. It deliberately
        # avoids protection groups and secure snapshots.
        Enabled = $false
        FrequencyValueSeconds = 3600
        FrequencySnapshotCount = 2
    }

    Protection = @{
        # Requires Lun.Enabled and LunGroup.Enabled. Snapshot consistency
        # rollback targets only the LUN created during this test run.
        Enabled = $true
    }

    QoS = @{
        # Requires Lun.Enabled and LunGroup.Enabled. The workflow creates a
        # SmartQoS policy on the test-owned LUN, toggles it, associates it with
        # the test-owned LUN group, and removes it during cleanup.
        Enabled = $true
    }

    Replication = @{
        # Disabled by default because these checks create remote replication
        # objects and can change DR state. Enable only on a lab pair and only
        # with remote LUNs intended for this validation run.
        Enabled = $false
        AllowDrMutation = $false
        AllowFailover = $false

        # Supply either RemoteDeviceId or RemoteDeviceName.
        RemoteDeviceId = ''
        RemoteDeviceName = ''

        # Supply either RemoteLunId or RemoteLunName. RemoteLunName is resolved
        # through Get-DMRemoteLun using the selected remote device.
        RemoteLunId = ''
        RemoteLunName = ''
        RemoteServiceType = 'ReplicationSecondaryLun'
    }

    HyperMetro = @{
        # Disabled by default because these checks create HyperMetro objects
        # and can suspend/start pairs. Enable only on a lab HyperMetro setup.
        Enabled = $false
        AllowDrMutation = $false
        AllowPrioritySwitch = $false

        # Supply either RemoteDeviceId or RemoteDeviceName.
        RemoteDeviceId = ''
        RemoteDeviceName = ''

        # Supply either RemoteLunId or RemoteLunName.
        RemoteLunId = ''
        RemoteLunName = ''
        RemoteServiceType = 'HyperMetroSecondaryLun'

        # Supply either DomainId or DomainName for an existing SAN domain.
        DomainId = ''
        DomainName = ''
    }

    Host = @{
        Enabled = $true
        OperatingSystem = 'Linux'
    }

    Nas = @{
        Enabled = $true
        FileSystemCapacityGB = 1

        # Leave as 0 to automatically expand the test-owned file system by
        # 1 GB over FileSystemCapacityGB, or set a larger explicit target
        # capacity in GB.
        ExpandedFileSystemCapacityGB = 0
        EnableDTree = $true
        EnableFileSystemSnapshot = $true
        EnableNfs = $true
        EnableCifs = $true

        # NFS client identity to grant on the export created by this test.
        # Example: '192.0.2.50' or 'validation.example.test'.
        NfsClientName = '192.0.2.50'

        # Requires EnableDTree = $true. The quota is created on the test-owned
        # dTree, then its space hard limit is raised by 10 GB and read back.
        EnableQuota = $true
        QuotaSpaceHardLimitGB = 10
    }

    Mapping = @{
        Enabled = $true
    }

    StoragePool = @{
        # Reversible rename round-trip on a PRE-EXISTING storage pool. This is the ONLY
        # storage-pool mutation the module performs and the only workflow that touches an
        # object it did not create: the module cannot create or delete pools, so safety
        # comes from full reversibility. The workflow reads the current name, renames the
        # named pool to a run-unique temporary name, reads it back, then renames it to its
        # original name and verifies restoration. A cleanup action restores the original
        # name if the run aborts mid-round-trip. No pool is created, deleted, resized, or
        # threshold/description-modified. Disabled by default.
        #
        # PoolName must be the EXACT name of a pool you accept being renamed and then
        # restored (never auto-picked). Leave blank to skip.
        Enabled = $true
        PoolName = 'StoragePool001'
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

    SystemManagement = @{
        # Master gate for the system-management mutation workflow. Disabled by
        # default: -RunMutatingTests alone never runs any of these sections.
        # Every sub-workflow creates only test-owned objects, captures their
        # identity immediately, and removes them by captured ID (or exact
        # recorded address) during the same run. Pre-existing SNMP, syslog,
        # user, and role configuration is never modified, matched by name
        # pattern, or cleaned.
        Enabled = $false

        # SNMP trap server create/update/test/remove using the address below.
        # Supply an address you own that is NOT already configured as a trap
        # target on the array (default: TEST-NET-1 documentation address).
        # Test-DMSnmpTrapServer sends a single test trap to this address only.
        AllowSnmpTrapServer = $false
        SnmpTrapServerAddress = '192.0.2.200'
        SnmpTrapServerPort = 16200

        # SNMP USM user create/update/remove with a run-unique name and
        # generated throwaway passwords (never persisted; the request trace
        # redacts password fields). Protocol codes per the REST reference:
        # auth '3' = HMAC-SHA, privacy '4' = AES. If the array security policy
        # rejects the generated user, the run reports it and continues.
        AllowSnmpUsmUser = $false
        SnmpUsmAuthProtocol = '3'
        SnmpUsmPrivacyProtocol = '4'

        # Syslog server add/remove by the exact address below. Supply an
        # address you own that is NOT already a configured syslog target.
        AllowSyslogServer = $false
        SyslogServerAddress = '192.0.2.201'

        # SECURITY-SENSITIVE, keep disabled unless explicitly reviewed for the
        # run: creates one test-owned role and one test-owned local user with a
        # generated throwaway password, updates both, then removes the user
        # before the role. Existing users/roles are never touched.
        # LocalRoleOwnerGroup: '1' = system group, '2' = vStore group.
        AllowLocalUserLifecycle = $false
        LocalRoleOwnerGroup = '1'
        LocalRoleSource = '1'
    }

    Network = @{
        # Master gate for the network mutation workflows. Disabled by default:
        # -RunMutatingTests alone never runs any network mutation. Network
        # changes are safety-sensitive -- a wrong mutation can sever management
        # or data access -- so every network workflow additionally requires its
        # own Allow* gate below.
        Enabled = $false

        # Test-owned failover-group lifecycle: create a run-unique customized
        # failover group, modify its description, verify the member getter
        # reports zero members, then remove it by the captured ID. Failover
        # groups are pure metadata objects; no port, VLAN, LIF, bond, route or
        # management address is touched. Member add/remove stays skipped until
        # a test-owned eligible member type exists (see
        # docs/network/safety-and-live-validation.md).
        AllowFailoverGroupLifecycle = $false

        # Test-owned VLAN lifecycle: create a run-unique VLAN on a verified-idle
        # parent port, then delete it by captured ID. Deferred and disabled by
        # default -- live VLAN create/delete is NOT run in the current release.
        # Enabling this gate alone does nothing: the workflow additionally
        # requires a parent port that the idle-port guard
        # (Get-DMVlanParentPortStatus) positively confirms is Idle, and the
        # harness owns no such port yet. Any live run remains a separate,
        # supervised, deferred session. See
        # docs/network/safety-and-live-validation.md.
        AllowVlanLifecycle = $false
    }

    Performance = @{
        # Master acknowledgement for the opt-in performance/capacity integrity
        # checks (Phases 1-5 of the performance implementation). The runner
        # additionally requires one of -IncludePerformance,
        # -IncludePerformanceHistory, -IncludeCapacityHistory or
        # -IncludeExcelPerformance; without both gates nothing runs and
        # existing validation output is unchanged.
        Enabled = $false

        # Acknowledges that -IncludePerformanceHistory / -IncludeCapacityHistory
        # may create report tasks on the array. Report tasks are metadata (no
        # storage objects are ever created); every created task is registered
        # by captured ID and removed again during the same run unless the
        # runner is called with -KeepCreatedReportTasks. Pre-existing report
        # tasks are snapshotted first and are never touched.
        AllowReportTaskCreation = $false

        # Acknowledges the optional monitoring round-trip test, which changes
        # the realtime sampling interval once and restores the captured
        # original in a finally block. Also requires -AllowMonitoringMutation
        # on the runner. Default runs never modify monitoring settings.
        AllowMonitoringMutation = $false

        # Lookback window (hours) for Get-DMPerformanceHistory checks. Keep
        # this small; zero returned rows are reported as NoData, not failure.
        HistoryLookbackHours = 2

        # retention_number used for report tasks created by the checks.
        ReportTaskRetentionNumber = 1
    }
}
