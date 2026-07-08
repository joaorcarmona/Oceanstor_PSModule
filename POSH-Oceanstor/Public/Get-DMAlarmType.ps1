function Get-DMAlarmType {
    <#
    .SYNOPSIS
        Gets the Huawei OceanStor alarm object-type catalog (read-only).

    .DESCRIPTION
        Returns the array's alarm object types (a human-readable name such as Port,
        Disk, or LUN paired with the numeric object-type value used by the
        alarm/event query filter, alarmObjType / CMO_ALARM_OBJ_TYPE).

        The catalog documented by GET ALARM_DEFINITION_OBJ ("Interface for Batch
        Querying Alarm Types", OceanStor Dorado 6.1.6 REST Interface Reference
        section 4.2.2.4.1) is fixed per firmware release and does not change at
        runtime, so this cmdlet serves it from an internal hardcoded list instead
        of calling the array on every invocation. The array is only queried as a
        fallback: when -ObjectType asks for a numeric value that is not present in
        the internal list (for example a type introduced by a newer firmware),
        that single lookup is resolved against GET ALARM_DEFINITION_OBJ.

        This cmdlet is reused by Get-DMAlarmHistory and Get-DMAlarmMasking to
        resolve an -AlarmObjectType name into its numeric filter value and to
        translate numeric object types back into friendly names.

    .PARAMETER WebSession
        Optional session to use if a storage fallback is required. If not defined,
        the module's cached $script:CurrentOceanstorSession session is used. No
        session is needed when the requested value is served from the internal
        list.

    .PARAMETER Name
        Optional. Return only the alarm object type(s) whose Name matches this
        value (case-insensitive, exact match). Resolved against the internal list;
        it does not trigger a storage fallback.

    .PARAMETER ObjectType
        Optional. Return only the alarm object type whose numeric object-type value
        (CMO_ALARM_OBJ_TYPE) matches this value. Served from the internal list when
        present; when absent (and -Database is Internal), the value is looked up
        against the array as a fallback.

    .PARAMETER Database
        Optional source selector. 'Internal' (the default) serves the catalog from
        the internal hardcoded list, querying the array only as a fallback when an
        -ObjectType value is not in that list. 'Storage' ignores the internal list
        entirely and queries the array directly (GET ALARM_DEFINITION_OBJ).

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        One object per alarm object type, with Name, ObjectType, and Id.

    .EXAMPLE
        PS C:\> Get-DMAlarmType

        Lists every alarm object type from the internal catalog (no array call).

    .EXAMPLE
        PS C:\> Get-DMAlarmType -Name disk

        Returns the disk alarm object type, exposing the ObjectType value to use
        with Get-DMAlarmHistory -AlarmObjectType.

    .EXAMPLE
        PS C:\> Get-DMAlarmType -WebSession $storage -ObjectType 60011

        Returns the object type whose numeric value is 60011, querying the array
        only if that value is not in the internal catalog.

    .EXAMPLE
        PS C:\> Get-DMAlarmType -WebSession $storage -Database Storage

        Bypasses the internal list and reads the live catalog from the array.

    .NOTES
        Filename: Get-DMAlarmType.ps1
        Read-only.

    .LINK
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 0, Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectType,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Internal', 'Storage')]
        [string]$Database = 'Internal'
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = 'Name', 'ObjectType'

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    # Shapes a single catalog row (from either the internal list or the array)
    # into the object contract callers expect: Name, ObjectType, Id.
    $newAlarmType = {
        param($TypeName, $TypeValue, $TypeId)
        $alarmType = [pscustomobject]@{
            Name       = $TypeName
            ObjectType = [string]$TypeValue
            Id         = [string]$TypeId
        }
        $alarmType | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        $alarmType
    }

    # Internal hardcoded catalog. Captured from GET ALARM_DEFINITION_OBJ?language=1
    # (Dorado 6.1.6). This list is fixed per firmware, so it is served without an
    # array round-trip; -ObjectType misses fall back to the live endpoint below.
    $catalogData = @'
Id,ObjectType,Name
0,6,Port
1,10,Disk
2,11,LUN
3,14,Host group
4,16,CPU
5,21,Host
6,23,Power module
7,27,Snapshot
8,29,File system snapshot
9,40,File system
10,49,Event
11,103,Performance
12,113,OM
13,156,vStore pair
14,157,ContainerImage
15,158,HelmChart
16,201,System
17,202,User
18,203,Domain
19,206,Enclosure
20,207,Controller
21,208,Expansion module
22,209,Interface module
23,210,BBU
24,211,Fan module
25,212,FC port
26,213,Ethernet port
27,216,Storage pool
28,218,SmartCache pool
29,219,LUN copy
30,220,Clone
31,221,Consistency group
32,222,iSCSI initiator
33,224,Remote device
34,234,SFP optical/electrical module
35,237,Memory
36,238,LDAP configuration
37,244,License
38,245,Mapping view
39,250,Remote LUN
40,253,LUN migration task
41,255,Host link
42,256,LUN group
43,257,Port group
44,263,Replication pair
45,266,Disk domain
46,267,Storage engine
47,269,QoS
48,279,LIF
49,280,VLAN
50,285,Anti-virus
51,289,Failover group
52,306,Assistant cooling unit
53,324,Bgp Peer
54,347,BGP Configuration
55,350,Dedupe and Compress
56,447,Cache
57,525,iSNS
58,558,Upgrade
59,562,Ethernet
60,580,Initiator
61,656,IPSEC_POLICY
62,678,vSwitch
63,813,MMC
64,815,Block device
65,818,DeviceManager for enterprise
66,822,Performance management
67,823,Server agent
68,8002,DEE
69,8003,DPS
70,8005,DPCC
71,15361,HyperMetro
72,15362,HyperMetro domain
73,15363,Quorum server
74,15364,HyperMetro consistency group
75,15365,Quorum server link
76,15366,HyperMetro vStore pair
77,16386,NAS protocol
78,16398,Protocol
79,16442,vStore
80,16445,Dtree
81,16446,Resource user
82,16449,DATATURBO service
83,16452,NFS service
84,16453,CIFS service
85,16458,File system quota
86,16494,NDMP
87,16497,Operation
88,16570,Back-end link
89,20480,Certificate management
90,50000,Storage unit
91,50001,Repository
92,50006,Backup plan
93,50007,Backup
94,50010,Copy
95,50011,Job
96,50012,Backup image
97,50013,Restore
98,50019,Alarm
99,50020,Server
100,50023,Process monitor
101,50028,System configuration
102,50029,System time
103,57435,chs_agent
104,57436,chs_collector
105,57439,workload_type
106,57454,disk_nvme_feature
107,57508,DR Star
108,57802,FS migration
109,57850,Smart GUI
110,57884,ContainerService
111,57885,ContainerApplication
112,57886,ContainerPod
113,57888,Network Plane
114,57895,LocalImageRepository
115,60002,Storage cluster
116,60011,Distributed protocol
'@ | ConvertFrom-Csv

    $catalog = New-Object System.Collections.ArrayList
    foreach ($row in $catalogData) {
        [void]$catalog.Add((& $newAlarmType $row.Name $row.ObjectType $row.Id))
    }

    # Full live-catalog fetch, shared by -Database Storage and the Internal
    # -ObjectType fallback. language=1 selects the English names (2 is Chinese);
    # ALARM_DEFINITION_OBJ documents only the language parameter and does not
    # support range paging, so this issues one direct request rather than
    # Invoke-DMPagedRequest (whose range-repeat guard would trip).
    $queryStorageCatalog = {
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'ALARM_DEFINITION_OBJ?language=1'
        $data = @($response | Select-DMResponseData)

        $live = New-Object System.Collections.ArrayList
        foreach ($item in $data) {
            [void]$live.Add((& $newAlarmType $item.CMO_ALARM_OBJ_NAME $item.CMO_ALARM_OBJ_TYPE $item.ID))
        }
        $live
    }

    # -Database Storage bypasses the internal list entirely and reads the live
    # catalog from the array, then applies any -ObjectType / -Name filters.
    if ($Database -eq 'Storage') {
        $result = @(& $queryStorageCatalog)
        if ($PSBoundParameters.ContainsKey('ObjectType')) {
            $result = @($result | Where-Object { $_.ObjectType -eq $ObjectType })
        }
        if ($PSBoundParameters.ContainsKey('Name')) {
            $result = @($result | Where-Object { $_.Name -eq $Name })
        }
        return $result
    }

    # -Database Internal (default): serve from the internal list. An -ObjectType
    # lookup falls back to the array only when the value is absent from that list
    # (a type this firmware baseline predates).
    if ($PSBoundParameters.ContainsKey('ObjectType')) {
        $hits = @($catalog | Where-Object { $_.ObjectType -eq $ObjectType })

        if ($hits.Count -eq 0) {
            $hits = @(& $queryStorageCatalog | Where-Object { $_.ObjectType -eq $ObjectType })
        }

        if ($PSBoundParameters.ContainsKey('Name')) {
            $hits = @($hits | Where-Object { $_.Name -eq $Name })
        }

        return $hits
    }

    # -Name filter is resolved against the internal list (case-insensitive, exact).
    if ($PSBoundParameters.ContainsKey('Name')) {
        return @($catalog | Where-Object { $_.Name -eq $Name })
    }

    return $catalog
}
