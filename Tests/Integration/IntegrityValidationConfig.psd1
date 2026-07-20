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
        Enabled = $true
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
        RemoteDeviceName = 'HWPTLABSTG004'

        # Supply either RemoteLunId or RemoteLunName. RemoteLunName is resolved
        # through Get-DMRemoteLun using the selected remote device.
        RemoteLunId = ''
        RemoteLunName = 'HyperReplica_Lun01'
        RemoteServiceType = 'ReplicationSecondaryLun'
    }

    HyperMetro = @{
        # Disabled by default because these checks create HyperMetro objects
        # and can suspend/start pairs. Enable only on a lab HyperMetro setup.
        Enabled = $false
        AllowDrMutation = $false
        AllowPrioritySwitch = $false

        # Force-start (HyperMetroPair/startup_node) forcibly brings up a pair and is
        # only meaningful in a genuine arbitration/outage scenario. It stays off by
        # default and independent of AllowPrioritySwitch/failover gates; enable only
        # on a lab pair intended for this validation run.
        AllowForceStart = $false

        # Supply either RemoteDeviceId or RemoteDeviceName.
        RemoteDeviceId = ''
        RemoteDeviceName = 'HWPTLABSTG004'

        # Supply either RemoteLunId or RemoteLunName.
        RemoteLunId = ''
        RemoteLunName = 'HyperMetro_Lun01'
        RemoteServiceType = 'HyperMetroSecondaryLun'

        # Supply either DomainId or DomainName for an existing SAN domain.
        DomainId = ''
        DomainName = 'BlockHyperMetroDomain_000'
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
        Enabled = $true

        # SNMP trap server create/update/test/remove using the address below.
        # Supply an address you own that is NOT already configured as a trap
        # target on the array (default: TEST-NET-1 documentation address).
        # Test-DMSnmpTrapServer sends a single test trap to this address only.
        AllowSnmpTrapServer = $true
        SnmpTrapServerAddress = '192.0.2.200'
        SnmpTrapServerPort = 16200

        # SNMP USM user create/update/remove with a run-unique name and
        # generated throwaway passwords (never persisted; the request trace
        # redacts password fields). Protocol codes per the REST reference:
        # auth '3' = HMAC-SHA, privacy '4' = AES. If the array security policy
        # rejects the generated user, the run reports it and continues.
        AllowSnmpUsmUser = $true
        SnmpUsmAuthProtocol = '3'
        SnmpUsmPrivacyProtocol = '4'

        # Syslog server add/remove by the exact address below. Supply an
        # address you own that is NOT already a configured syslog target.
        AllowSyslogServer = $true
        SyslogServerAddress = '192.0.2.201'

        # SECURITY-SENSITIVE, keep disabled unless explicitly reviewed for the
        # run: creates one test-owned role and one test-owned local user with a
        # generated throwaway password, updates both, then removes the user
        # before the role. Existing users/roles are never touched.
        # LocalRoleOwnerGroup: '1' = system group, '2' = vStore group.
        AllowLocalUserLifecycle = $true
        LocalRoleOwnerGroup = '1'
        LocalRoleSource = '1'
    }

    Network = @{
        # Master gate for the network mutation workflows. Disabled by default:
        # -RunMutatingTests alone never runs any network mutation. Network
        # changes are safety-sensitive -- a wrong mutation can sever management
        # or data access -- so every network workflow additionally requires its
        # own Allow* gate below.
        Enabled = $true

        # Test-owned failover-group lifecycle: create a run-unique customized
        # failover group, modify its description, verify the member getter
        # reports zero members, then remove it by the captured ID. Failover
        # groups are pure metadata objects; no port, VLAN, LIF, bond, route or
        # management address is touched. Member add/remove stays skipped until
        # a test-owned eligible member type exists (see
        # docs/network/safety-and-live-validation.md).
        AllowFailoverGroupLifecycle = $true

        # Test-owned VLAN lifecycle: create a run-unique VLAN on a verified-idle
        # parent port, then delete it by captured ID. Deferred and disabled by
        # default -- live VLAN create/delete is NOT run in the current release.
        # Enabling this gate alone does nothing: the workflow additionally
        # requires a parent port that the idle-port guard
        # (Get-DMVlanParentPortStatus) positively confirms is Idle, and the
        # harness owns no such port yet. Any live run remains a separate,
        # supervised, deferred session. See
        # docs/network/safety-and-live-validation.md.
        AllowVlanLifecycle = $true

        # Operator-supervised, config-gated live network-stack workflows. These
        # CREATE AND DESTROY real bonds, VLANs, LIFs and a failover group on the
        # operator-designated ports below, so they run ONLY when the runner is
        # called with -RunSupervisedTests AND this block's Enabled = $true (the
        # -RunMutatingTests switch never triggers them). A human must be present
        # and the ports must be verified link-down/idle. Every object is
        # test-owned (dm_integrity_<runId>_*), captured by ID, and removed in
        # reverse creation order within the same run. See
        # docs/network/safety-and-live-validation.md. All gates disabled by default.
        Supervised = @{
            # Master gate for the supervised network-stack workflows.
            Enabled = $true

            # Bond + 4 VLANs (PortType 7) + 4 role-LIFs stack. Mirrors
            # Tests/Prompts/prompt-network-stack-supervised-test.md (live-validated
            # 2026-07-09). Uses the first four VlanTags below.
            AllowNetworkStackLifecycle = $true

            # Failover group + 2 VLAN members (PortType 1) + service LIF stack.
            # Mirrors Tests/Prompts/prompt-network-failovergroup-supervised-test.md.
            # Uses the first two VlanTags below.
            AllowFailoverGroupStackLifecycle = $true

            # Two same-controller front-end port pairs (their Location values),
            # reusable between runs. Pair A builds bond A on controller A; pair B
            # builds bond B on controller B, so the failover-group stack spans
            # controllers via one bond per controller. The net stack uses pair A
            # only. All four ports must be front-end, link-down, unbonded, no LIF,
            # no child VLAN -- re-verified read-only before anything is created.
            PortLocationsA = @('CTE0.A.IOM0.P2', 'CTE0.A.IOM0.P3')
            PortLocationsB = @('CTE0.B.IOM0.P2', 'CTE0.B.IOM0.P3')

            # VLAN tags from the reserved 130-140 range. The net stack uses the
            # first four (one VLAN per tag on bond A). The failover-group stack uses
            # only the first tag, shared across both bonds' VLANs (a failover group
            # requires its member VLANs to share one tag id).
            VlanTags = @(130, 131, 132, 133)

            # LIF IPv4 address format: {0} is substituted with the VLAN tag, e.g.
            # tag 130 -> 10.130.10.1. Paired with IpMask below (a /24 subnet).
            IpAddressFormat = '10.{0}.10.1'
            IpMask = '255.255.255.0'

            # Service LIF on the failover-group stack: Role 2 = service,
            # SupportProtocol 3 = NFS+CIFS, FailbackMode 1 = manual. CanFailover
            # binds the LIF to the failover group so its service IP can move.
            LifRole = 2
            LifSupportProtocol = 3
            LifCanFailover = $true
            LifFailbackMode = 1

            # Invoke the read-only idle-port guard (Get-DMVlanParentPortStatus) and
            # record its verdict WITHOUT gating on it. On lab arrays it reports
            # InUse for every port (the built-in System-defined failover group owns
            # them all); recording this confirms that calibration finding.
            RecordGuardDryRun = $true
        }
    }

    Performance = @{
        # Master acknowledgement for the opt-in performance/capacity integrity
        # checks (Phases 1-5 of the performance implementation). The runner
        # additionally requires one of -IncludePerformance,
        # -IncludePerformanceHistory, -IncludeCapacityHistory or
        # -IncludeExcelPerformance; without both gates nothing runs and
        # existing validation output is unchanged.
        Enabled = $true

        # Acknowledges that -IncludePerformanceHistory / -IncludeCapacityHistory
        # may create report tasks on the array. Report tasks are metadata (no
        # storage objects are ever created); every created task is registered
        # by captured ID and removed again during the same run unless the
        # runner is called with -KeepCreatedReportTasks. Pre-existing report
        # tasks are snapshotted first and are never touched.
        AllowReportTaskCreation = $true

        # Acknowledges the optional monitoring round-trip test, which changes
        # the realtime sampling interval once and restores the captured
        # original in a finally block. Also requires -AllowMonitoringMutation
        # on the runner. Default runs never modify monitoring settings.
        AllowMonitoringMutation = $true

        # Lookback window (hours) for Get-DMPerformanceHistory checks. Keep
        # this small; zero returned rows are reported as NoData, not failure.
        HistoryLookbackHours = 2

        # retention_number used for report tasks created by the checks.
        ReportTaskRetentionNumber = 1
    }
}
