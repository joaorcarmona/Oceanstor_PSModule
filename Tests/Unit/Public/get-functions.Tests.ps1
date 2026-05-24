BeforeDiscovery {
    $script:getFunctionsModule = New-Module -Name GetFunctionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function invoke-DeviceManager {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiators.ps1"

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Private" -Filter 'class-*.ps1' |
            Where-Object Name -ne 'class-OceanStorMappingView.ps1' |
            ForEach-Object { . $_.FullName }

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Public" -Filter 'get-*.ps1' |
            ForEach-Object { . $_.FullName }

        Export-ModuleMember -Function 'get-*'
    }

    Import-Module $script:getFunctionsModule -Force
}

AfterAll {
    Remove-Module -Name GetFunctionsTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope GetFunctionsTestModule {
Describe 'Public getter functions' {
    BeforeAll {
        $script:eLabel = @(
            'BoardType=board-01'
            'BarCode=serial-01'
            'Item=part-01'
            'Description=component'
            'Manufactured=2026-01-01'
            'VendorName=Huawei'
        ) -join "`n"

        function script:New-TestDisk {
            param(
                [string]$Id = 'disk-01',
                [string]$Location = 'DAE000.1',
                [string]$PoolId = 'pool-01',
                [string]$PoolName = 'performance',
                [string]$LogicType = '1',
                [string]$IsCofferDisk = 'FALSE'
            )

            [pscustomobject]@{
                ID = $Id; LOCATION = $Location; POOLID = $PoolId; POOLNAME = $PoolName
                LOGICTYPE = $LogicType; ISCOFFERDISK = $IsCofferDisk; barcode = '00PARTNUM01'
                ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 27
                TYPE = 10; DISKTYPE = 14; DISKFORM = 3; manuCapacity = 1GB
            }
        }

        function script:New-TestLun {
            param([string]$Id = 'lun-01', [string]$Name = 'data-lun', [string]$WWN = 'wwn-01')

            [pscustomobject]@{
                ID = $Id; NAME = $Name; WWN = $WWN; TYPE = 11; SECTORSIZE = 512
                CAPACITY = 2097152; ALLOCCAPACITY = 1048576; HEALTHSTATUS = 1
                RUNNINGSTATUS = 27; ALLOCTYPE = 1; mapped = $true
            }
        }

        function script:New-TestLunSnapshot {
            [pscustomobject]@{
                ID = 'snap-01'; NAME = 'before-patch'; SOURCELUNID = 'lun-01'; SOURCELUNNAME = 'data-lun'
                DESCRIPTION = 'Before patching'; HEALTHSTATUS = 1; RUNNINGSTATUS = 43; WWN = 'snap-wwn-01'
                USERCAPACITY = 2097152; CONSUMEDCAPACITY = 1024; IOPRIORITY = 2; isReadOnly = $true
            }
        }
    }

    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
        Mock invoke-DeviceManager { [pscustomobject]@{ data = @() } }
    }

    Describe 'Hardware getter functions' {
        It 'gets alarms using the requested alarm state' {
            Mock invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ name = 'warning'; alarmStatus = 2; level = 2; type = 1; eventType = 1; clearTime = 0; recoverTime = 0; startTime = 0 }) }
            }

            $result = get-DMAlarms -WebSession $script:session -AlarmStatus Cleared

            $result[0].Name | Should -Be 'warning'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Name', 'Level', 'Alarm Status', 'Location', 'Start time')
            $result[0].'Event Type' | Should -Be 'alarm'
            $result[0].Session | Should -Be $script:session
        }

        It 'gets battery backup units' {
            Mock invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'bbu-01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 210; VOLTAGE = 120; REMAINLIFEDAYS = 30 }) }
            }

            $result = get-DMbbus -WebSession $script:session

            $result[0].Id | Should -Be 'bbu-01'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'PSU Location', 'Health Status', 'Running Status', 'Remaining Life')
            $result[0].'Part Number' | Should -Be 'part-01'
        }

        It 'gets controllers' {
            Mock invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'ctrl-01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 207; MEMORYSIZE = 1GB }) }
            }

            $result = (get-DMControllers -WebSession $script:session)[0]

            $result.Id | Should -Be 'ctrl-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Running Status', 'Is Master')
            $result.'Memory Size' | Should -Be 1
        }

        It 'gets enclosures' {
            Mock invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'enc-01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; TYPE = 206; MODEL = 17 }) }
            }

            $result = (get-DMEnclosures -WebSession $script:session)[0]

            $result.Id | Should -Be 'enc-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Model')
            $result.'Part Number' | Should -Be 'part-01'
        }

        It 'gets interface modules' {
            Mock invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'module-01'; ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 209; MODEL = 2307 }) }
            }

            $result = (get-DMInterfaceModules -WebSession $script:session)[0]

            $result.Id | Should -Be 'module-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Model')
            $result.'Part Number' | Should -Be 'part-01'
        }
    }

    Describe 'Disk getter functions' {
        BeforeEach {
            Mock invoke-DeviceManager {
                [pscustomobject]@{ data = @(
                    (New-TestDisk -Id 'disk-free' -Location 'DAE000.1' -PoolId 'pool-01' -PoolName 'performance')
                    (New-TestDisk -Id 'disk-coffer' -Location 'DAE001.2' -PoolId 'pool-02' -PoolName 'capacity' -LogicType '2' -IsCofferDisk 'TRUE')
                ) }
            }
        }

        It 'gets all disks' {
            $result = @(get-DMdisks -WebSession $script:session)

            $result.Count | Should -Be 2
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
            $result[0].'Part Number' | Should -Be 'part-01'
        }

        It 'gets disks by location' {
            $result = (get-DMDiskbyLocation -WebSession $script:session -Location 'DAE001')[0]

            $result.id | Should -Be 'disk-coffer'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }

        It 'gets disks by pool id' {
            $result = (get-DMdisksbyPoolId -WebSession $script:session -PoolId 'pool-01')[0]

            $result.id | Should -Be 'disk-free'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }

        It 'gets disks by pool name' {
            $result = (get-DMdisksbyPoolName -WebSession $script:session -PoolName 'capacity')[0]

            $result.id | Should -Be 'disk-coffer'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }

        It 'gets coffer disks' {
            $result = (get-DMcofferDisks -WebSession $script:session)[0]

            $result.id | Should -Be 'disk-coffer'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }

        It 'gets free disks' {
            $result = (get-DMfreeDisks -WebSession $script:session)[0]

            $result.id | Should -Be 'disk-free'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }
    }

    Describe 'Host getter functions' {
        BeforeEach {
            $script:hostRecords = @(
                [pscustomobject]@{ ID = 'host-01'; NAME = 'server-a'; PARENTTYPE = 14; PARENTID = 'group-01'; PARENTNAME = 'cluster-a'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 21 }
                [pscustomobject]@{ ID = 'host-02'; NAME = 'server-b'; PARENTTYPE = 14; PARENTID = 'group-02'; PARENTNAME = 'cluster-b'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 21 }
            )
        }

        It 'gets hosts' {
            Mock invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch ($Resource) {
                    'host' { [pscustomobject]@{ data = $script:hostRecords } }
                    'fc_initiator?PARENTID=host-01' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fc-01'; TYPE = 223; PARENTID = 'host-01' }) } }
                    'iscsi_initiator?PARENTID=host-01' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'iscsi-01'; TYPE = 222; PARENTID = 'host-01' }) } }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = @(get-DMhosts -WebSession $script:session)

            $result.Count | Should -Be 2
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result[0].'Parent Id' | Should -Be 'group-01'
            $result[0].initiators.Id | Should -Be @('fc-01', 'iscsi-01')
            $result[1].initiators | Should -BeNullOrEmpty
        }

        It 'gets hosts by id through the filtered endpoint' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @($script:hostRecords[0]) } }

            $result = (get-DMhostsbyId -WebSession $script:session -HostId 'host-01')[0]

            $result.id | Should -Be 'host-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'gets hosts by name through the filtered endpoint' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @($script:hostRecords[0]) } }

            $result = (get-DMhostsbyName -WebSession $script:session -Name 'server-a')[0]

            $result.name | Should -Be 'server-a'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'gets hosts by host group id' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = $script:hostRecords } }

            $result = (get-DMhostsbyHostGroupId -WebSession $script:session -HostGroupId 'group-01')[0]

            $result.id | Should -Be 'host-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'gets hosts by host group name' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = $script:hostRecords } }

            $result = (get-DMhostsbyHostGroupName -WebSession $script:session -HostGroupName 'cluster-b')[0]

            $result.id | Should -Be 'host-02'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-02'
        }

        It 'gets host groups' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 4; NAME = 'cluster'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }) } }

            $result = (get-DMhostGroups -WebSession $script:session)[0]

            $result.Name | Should -Be 'cluster'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Is Mapped', 'Host Member Number', 'vStore Name')
            $result.Description | Should -BeNullOrEmpty
        }

        It 'gets FC host links for a host' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'link-01'; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; TARGET_TYPE = 212; TYPE = 255 }) } }

            $result = (get-DMHostLinks -WebSession $script:session -HostId 'host-01' -InitiatorType FC)[0]

            $result.Id | Should -Be 'link-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Host Name', 'Initiator Type', 'Target Type', 'Running Status')
            $result.'Health Status' | Should -Be 'normal'
        }

        It 'gets all fibre channel initiators' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fc-01'; TYPE = 223; RUNNINGSTATUS = 27; vstoreid = 4294967295 }) } }

            $result = (get-DMHostInitiators -WebSession $script:session -InitatorType FibreChannel)[0]

            $result.Type | Should -Be 'FC Initiator'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
            $result.'vStore ID' | Should -Be 4294967295
        }

        It 'gets free iSCSI initiators' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'iscsi-01'; TYPE = 222; ISFREE = $true; vstoreid = 4294967295 }) } }

            $result = (get-DMHostInitiators -WebSession $script:session -InitatorType ISCSI -FreeInitiators)[0]

            $result.Type | Should -Be 'ISCSI Initiator'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
            $result.'vStore ID' | Should -Be 4294967295
        }

        It 'returns no initiators when the requested protocol has no data' {
            Mock invoke-DeviceManager { [pscustomobject]@{ error = [pscustomobject]@{ code = 0 } } }

            $result = @(get-DMHostInitiators -WebSession $script:session -HostId 'host-fc-only' -InitatorType ISCSI)

            $result | Should -BeNullOrEmpty
        }
    }

    Describe 'Network getter functions' {
        It 'gets DNS servers' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = [pscustomobject]@{ ADDRESS = '["10.0.0.1","10.0.0.2"]' } } }

            $result = get-DMdnsServer -WebSession $script:session

            $result['DNS Server 1'] | Should -Be '10.0.0.1'
            $result['DNS Server 2'] | Should -Be '10.0.0.2'
        }

        It 'gets logical interfaces' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'lif-01'; ADDRESSFAMILY = 0; SUPPORTPROTOCOL = 3 }) } }

            $result = (get-DMLifs -WebSession $script:session)[0]

            $result.Id | Should -Be 'lif-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'LIF Name', 'IPv4 Address', 'Running Status', 'Support Protocol')
            $result.'Address Family' | Should -Be 'IPv4'
        }

        It 'gets bond ports' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'bond-01'; NAME = 'bond0'; TYPE = 235 }) } }

            $result = (get-DMPortBond -WebSession $script:session)[0]

            $result.Id | Should -Be 'bond-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Ethernet Ports')
            $result.'Port Type' | Should -Be 'Bond Port'
        }

        It 'gets Ethernet ports' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'eth-01'; NAME = 'eth0'; TYPE = 213 }) } }

            $result = (get-DMPortETH -WebSession $script:session)[0]

            $result.Id | Should -Be 'eth-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'IPv4 Address')
            $result.'Port Type' | Should -Be 'Ethernet Port'
        }

        It 'gets fibre channel ports' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fc-01'; NAME = 'fc0'; TYPE = 212 }) } }

            $result = (get-DMPortFc -WebSession $script:session)[0]

            $result.Id | Should -Be 'fc-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'WWN')
            $result.'Port Type' | Should -Be 'Fibre Channel'
        }

        It 'gets SAS ports' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'sas-01'; NAME = 'sas0'; TYPE = 214 }) } }

            $result = (get-DMPortSAS -WebSession $script:session)[0]

            $result.Id | Should -Be 'sas-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Port Location')
            $result.'Port Type' | Should -Be 'SAS Port'
        }

        It 'gets VLAN interfaces' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'vlan-01'; TYPE = 280; TAG = 100 }) } }

            $result = (get-DMvLans -WebSession $script:session)[0]

            $result.Id | Should -Be 'vlan-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Vlan Tag Id', 'Port Type', 'Running Status')
            $result.Type | Should -Be 'VLAN'
        }
    }

    Describe 'Storage getter functions' {
        It 'gets file systems' {
            Mock invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = '0'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27 }) }
            }

            $result = (get-DMFileSystem -WebSession $script:session)[0]

            $result.Id | Should -Be 'fs-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Capacity (GB)')
            $result.RealCapacity | Should -Be 2097152
        }

        It 'gets LUN groups' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'luns'; GROUPTYPE = 0; CAPCITY = 1GB }) } }

            $result = (get-DMlunGroups -WebSession $script:session)[0]

            $result.Id | Should -Be 12
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'LunGroup Capacity', 'Is Mapped', 'Luns Members number')
            $result.Description | Should -BeNullOrEmpty
        }

        It 'retrieves LUN objects associated with a LUN group through its method' {
            Mock invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch ($Resource) {
                    'lungroup' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'luns'; GROUPTYPE = 0; CAPCITY = 1GB }) } }
                    'lungroup/12' { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '["lun-02"]' } } }
                    'lun' { [pscustomobject]@{ data = @((New-TestLun -Id 'lun-01' -Name 'database'), (New-TestLun -Id 'lun-02' -Name 'archive')) } }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $lunGroup = (get-DMlunGroups -WebSession $script:session)[0]
            $result = @($lunGroup.GetLuns())

            $result.Name | Should -Be @('archive')
            $result[0].GetType().Name | Should -Be 'OceanstorLunv6'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size', 'WWN')
        }

        It 'returns no LUNs for an empty LUN group association list' {
            Mock invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch ($Resource) {
                    'lungroup' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'empty-luns'; GROUPTYPE = 0; CAPCITY = 0 }) } }
                    'lungroup/12' { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '[]' } } }
                }
            }

            $lunGroup = (get-DMlunGroups -WebSession $script:session)[0]
            $result = @($lunGroup.GetLuns())

            $result | Should -BeNullOrEmpty
            Should -Invoke invoke-DeviceManager -ParameterFilter { $Resource -eq 'lun' } -Times 0 -Exactly
        }

        It 'gets version 6 LUNs' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @(New-TestLun) } }

            $result = get-DMluns -WebSession $script:session

            $result[0].Id | Should -Be 'lun-01'
            $result[0].GetType().Name | Should -Be 'OceanstorLunv6'
        }

        It 'gets LUN snapshots' {
            Mock invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:snapshotGetSession = $WebSession
                $script:snapshotGetMethod = $Method
                $script:snapshotGetResource = $Resource
                [pscustomobject]@{ data = @(New-TestLunSnapshot) }
            }

            $result = get-DMLunSnapshots -WebSession $script:session

            $result[0].GetType().Name | Should -Be 'OceanstorLunSnapshot'
            $result[0].Id | Should -Be 'snap-01'
            $result[0].'Source Lun Name' | Should -Be 'data-lun'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Source Lun Name', 'Health Status', 'Running Status')
            $script:snapshotGetSession | Should -Be $script:session
            $script:snapshotGetMethod | Should -Be 'GET'
            $script:snapshotGetResource | Should -Be 'snapshot'
        }

        It 'gets LUN snapshots filtered by source LUN name' {
            Mock invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch ($Resource) {
                    'lun' { [pscustomobject]@{ data = @(New-TestLun) } }
                    'snapshot?filter=SOURCELUNID:lun-01' {
                        $script:snapshotFilterResource = $Resource
                        [pscustomobject]@{ data = @(New-TestLunSnapshot) }
                    }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = get-DMLunSnapshots -WebSession $script:session -LunName 'data-lun'

            $result[0].Id | Should -Be 'snap-01'
            $script:snapshotFilterResource | Should -Be 'snapshot?filter=SOURCELUNID:lun-01'
        }

        It 'rejects an invalid source LUN name for snapshot filtering' {
            Mock invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                [pscustomobject]@{ data = @(New-TestLun) }
            }

            { get-DMLunSnapshots -WebSession $script:session -LunName 'missing' } |
                Should -Throw '*Invalid LunName*'
        }

        It 'gets LUNs by filter' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @((New-TestLun -Id 'lun-01' -Name 'finance'), (New-TestLun -Id 'lun-02' -Name 'archive')) } }

            $result = (get-DMLunsbyFilter -WebSession $script:session -Filter Name -Keyword finance)[0]

            $result.Id | Should -Be 'lun-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size', 'WWN')
            $result.'Allocation Type' | Should -Be 'Thin'
        }

        It 'gets a LUN by WWN' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @((New-TestLun -Id 'lun-01' -WWN 'wwn-a'), (New-TestLun -Id 'lun-02' -WWN 'wwn-b')) } }

            $result = (get-DMlunsByWWN -WebSession $script:session -WWN 'wwn-b')[0]

            $result.Id | Should -Be 'lun-02'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size', 'WWN')
            $result.'Allocation Type' | Should -Be 'Thin'
        }

        It 'gets NFS file clients' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'client-01'; NAME = '10.0.0.0/24'; ACCESSVAL = 1; CHARSET = 0 }) } }

            $result = (get-DMnfsFileClient -WebSession $script:session)[0]

            $result.Id | Should -Be 'client-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'NFS Share Name', 'Access Permission', 'WriteMode')
            $result.'Charset Encoding' | Should -Be 'UTF-8'
        }

        It 'gets CIFS shares' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'cifs-01'; NAME = 'share'; subType = 0 }) } }

            $result = (get-DMShares -WebSession $script:session -ShareType CIFS)[0]

            $result.Id | Should -Be 'cifs-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Share Path', 'FileSystem ID', 'vStore Name')
            $result.'Sub Type' | Should -Be 'normal'
        }

        It 'gets NFS shares' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'nfs-01'; NAME = 'export'; CHARACTERENCODING = 0 }) } }

            $result = (get-DMShares -WebSession $script:session -ShareType NFS)[0]

            $result.Id | Should -Be 'nfs-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Share Path', 'FileSystem ID', 'vStore Name')
            $result.'Character Enconding' | Should -Be 'UTF-8'
        }

        It 'gets storage pools' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'pool-01'; NAME = 'pool'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; DATASPACE = (512 * 1GB) }) } }

            $result = (get-DMstoragePools -WebSession $script:session)[0]

            $result.id | Should -Be 'pool-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'DataSpace')
            $result.dataspace | Should -Be 1
        }

        It 'gets system information' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = '@{ID=system-01;PRODUCTVERSION=V600R001;HEALTHSTATUS=1;RUNNINGSTATUS=1;HOTSPAREDISKSCAPACITY=2}' } }

            $result = get-DMSystem -WebSession $script:session

            $result.sn | Should -Be 'system-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('sn', 'version', 'Health Status', 'Running Status', 'WWN')
            $result.HotSpareNumbers | Should -Be 2
        }

        It 'gets vStores' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 7; NAME = 'tenant-a'; RUNNINGSTATUS = 1 }) } }

            $result = (get-DMvStore -WebSession $script:session)[0]

            $result.Name | Should -Be 'tenant-a'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Running Status', 'SAN Free Capacity Quota', 'NAS Free Capacity Quota')
            $result.Description | Should -BeNullOrEmpty
        }

        It 'gets workload types' {
            Mock invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'workload-01'; NAME = 'db'; CREATETYPE = 1; BLOCKSIZE = 2 }) } }

            $result = (get-DMWorkLoadTypes -WebSession $script:session)[0]

            $result.Id | Should -Be 'workload-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Workload Type', 'Block Size', 'Compression Enabled')
            $result.'Block Size' | Should -Be '16 KB'
        }

        It 'gets workload types by filter' {
            Mock invoke-DeviceManager {
                [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'workload-01'; NAME = 'db'; CREATETYPE = 1; ENABLECOMPRESS = $true }
                    [pscustomobject]@{ ID = 'workload-02'; NAME = 'archive'; CREATETYPE = 1; ENABLECOMPRESS = $false }
                ) }
            }

            $result = (get-DMWorkLoadTypesbyFilter -WebSession $script:session -Filter 'Compression Enabled' -Keyword enabled)[0]

            $result.Id | Should -Be 'workload-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Workload Type', 'Block Size', 'Compression Enabled')
            $result.'Compression Enabled' | Should -Be 'enabled'
        }
    }
}
}
