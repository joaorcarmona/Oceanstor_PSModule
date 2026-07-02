BeforeDiscovery {
    $script:getStorageModule = New-Module -Name GetStorageTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Private" -Filter 'class-*.ps1' |
            Where-Object Name -notin 'class-OceanStorMappingView.ps1', 'class-OceanstorSession.ps1' |
            ForEach-Object { . $_.FullName }

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Public" -Filter 'Get-*.ps1' |
            ForEach-Object { . $_.FullName }

        Export-ModuleMember -Function 'Get-*'
    }

    Import-Module $script:getStorageModule -Force
}

AfterAll {
    Remove-Module -Name GetStorageTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope GetStorageTestModule {
Describe 'Public getter functions' {
    BeforeAll {
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
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }
    }
    Describe 'Storage getter functions' {
        It 'gets file systems' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = '0'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27 }) }
            }

            $result = (Get-DMFileSystem -WebSession $script:session)[0]

            $result.Id | Should -Be 'fs-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Capacity (GB)')
            $result.RealCapacity | Should -Be 2097152
        }

        It 'gets LUN groups' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'luns'; GROUPTYPE = 0; CAPCITY = 1GB }) } }

            $result = (Get-DMlunGroup -WebSession $script:session)[0]

            $result.Id | Should -Be 12
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'LunGroup Capacity', 'Is Mapped', 'Luns Members number')
            $result.Description | Should -BeNullOrEmpty
        }

        It 'retrieves LUN objects associated with a LUN group through its method' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch -Wildcard ($Resource) {
                    'lungroup/12'  { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '["lun-02"]' } }; break }
                    'lungroup*'    { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'luns'; GROUPTYPE = 0; CAPCITY = 1GB }) }; break }
                    'lun*'         { [pscustomobject]@{ data = @((New-TestLun -Id 'lun-01' -Name 'database'), (New-TestLun -Id 'lun-02' -Name 'archive')) }; break }
                    default        { [pscustomobject]@{ data = @() } }
                }
            }

            $lunGroup = (Get-DMlunGroup -WebSession $script:session)[0]
            $result = @($lunGroup.GetLuns())

            $result.Name | Should -Be @('archive')
            $result[0].GetType().Name | Should -Be 'OceanstorLunv6'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size', 'WWN')
        }

        It 'returns no LUNs for an empty LUN group association list' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch ($Resource) {
                    'lungroup' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'empty-luns'; GROUPTYPE = 0; CAPCITY = 0 }) } }
                    'lungroup/12' { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '[]' } } }
                }
            }

            $lunGroup = (Get-DMlunGroup -WebSession $script:session)[0]
            $result = @($lunGroup.GetLuns())

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-DeviceManager -ParameterFilter { $Resource -eq 'lun' } -Times 0 -Exactly
        }

        It 'gets version 6 LUNs' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @(New-TestLun) } }

            $result = Get-DMlun -WebSession $script:session

            $result[0].Id | Should -Be 'lun-01'
            $result[0].GetType().Name | Should -Be 'OceanstorLunv6'
        }

        It 'gets LUN snapshots' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:snapshotGetSession = $WebSession
                $script:snapshotGetMethod = $Method
                $script:snapshotGetResource = $Resource
                [pscustomobject]@{ data = @(New-TestLunSnapshot) }
            }

            $result = Get-DMLunSnapshot -WebSession $script:session

            $result[0].GetType().Name | Should -Be 'OceanstorLunSnapshot'
            $result[0].Id | Should -Be 'snap-01'
            $result[0].'Source Lun Name' | Should -Be 'data-lun'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Source Lun Name', 'Health Status', 'Running Status')
            $script:snapshotGetSession | Should -Be $script:session
            $script:snapshotGetMethod | Should -Be 'GET'
            $script:snapshotGetResource | Should -BeLike 'snapshot*'
        }

        It 'gets LUN snapshots filtered by source LUN name' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch -Wildcard ($Resource) {
                    'lun*' { [pscustomobject]@{ data = @(New-TestLun) } }
                    'snapshot?filter=SOURCELUNID::lun-01*' {
                        $script:snapshotFilterResource = $Resource
                        [pscustomobject]@{ data = @(New-TestLunSnapshot) }
                    }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = Get-DMLunSnapshot -WebSession $script:session -LunName 'data-lun'

            $result[0].Id | Should -Be 'snap-01'
            $script:snapshotFilterResource | Should -BeLike 'snapshot?filter=SOURCELUNID::lun-01*'
        }

        It 'rejects an invalid source LUN name for snapshot filtering' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                [pscustomobject]@{ data = @(New-TestLun) }
            }

            { Get-DMLunSnapshot -WebSession $script:session -LunName 'missing' } |
                Should -Throw '*Invalid LunName*'
        }

        It 'gets LUNs by filter using an exact server-side query for known fields' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:filterResource = $Resource
                [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') }
            }

            $result = (Get-DMLunsbyFilter -WebSession $script:session -Filter Name -Keyword finance)[0]

            $result.Id | Should -Be 'lun-01'
            $script:filterResource | Should -Be 'lun?filter=NAME::finance'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size', 'WWN')
            $result.'Allocation Type' | Should -Be 'Thin'
        }

        It 'gets LUNs by filter using a fuzzy server-side hint for a wildcard keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:filterResource = $Resource
                if ($Resource -eq 'lun?filter=NAME:fin') {
                    return [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMLunsbyFilter -WebSession $script:session -Filter Name -Keyword 'fin*')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-01'
            $script:filterResource | Should -Be 'lun?filter=NAME:fin'
        }

        It 'gets LUNs by filter using client-side exact match for unmapped properties' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:filterResource = $Resource
                [pscustomobject]@{ data = @((New-TestLun -Id 'lun-01' -Name 'finance'), (New-TestLun -Id 'lun-02' -Name 'archive')) }
            }

            $result = @(Get-DMLunsbyFilter -WebSession $script:session -Filter 'Allocation Type' -Keyword 'Thin')

            $script:filterResource | Should -Be 'lun'
            $result.Count | Should -Be 2
        }

        It 'gets a LUN by WWN using server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:wwnResource = $Resource
                [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -WWN 'wwn-b') }
            }

            $result = (Get-DMlunByWWN -WebSession $script:session -WWN 'wwn-b')[0]

            $result.Id | Should -Be 'lun-02'
            $script:wwnResource | Should -Be 'lun?filter=WWN:wwn-b'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size', 'WWN')
            $result.'Allocation Type' | Should -Be 'Thin'
        }

        It 'gets NFS file clients' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'client-01'; NAME = '10.0.0.0/24'; ACCESSVAL = 1; CHARSET = 0 }) } }

            $result = (Get-DMnfsFileClient -WebSession $script:session)[0]

            $result.Id | Should -Be 'client-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'NFS Share Name', 'Access Permission', 'WriteMode')
            $result.'Charset Encoding' | Should -Be 'UTF-8'
        }

        It 'gets CIFS shares' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'cifs-01'; NAME = 'share'; subType = 0 }) } }

            $result = (Get-DMShare -WebSession $script:session -ShareType CIFS)[0]

            $result.Id | Should -Be 'cifs-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Share Path', 'FileSystem ID', 'vStore Name')
            $result.'Sub Type' | Should -Be 'normal'
        }

        It 'gets NFS shares' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'nfs-01'; NAME = 'export'; CHARACTERENCODING = 0 }) } }

            $result = (Get-DMShare -WebSession $script:session -ShareType NFS)[0]

            $result.Id | Should -Be 'nfs-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Share Path', 'FileSystem ID', 'vStore Name')
            $result.'Character Enconding' | Should -Be 'UTF-8'
        }

        It 'gets storage pools' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'pool-01'; NAME = 'pool'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; DATASPACE = (512 * 1GB) }) } }

            $result = (Get-DMstoragePool -WebSession $script:session)[0]

            $result.id | Should -Be 'pool-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'DataSpace')
            $result.dataspace | Should -Be 1
        }

        It 'gets system information' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = '@{ID=system-01;PRODUCTVERSION=V600R001;HEALTHSTATUS=1;RUNNINGSTATUS=1;HOTSPAREDISKSCAPACITY=2}' } }

            $result = Get-DMSystem -WebSession $script:session

            $result.sn | Should -Be 'system-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('sn', 'version', 'Health Status', 'Running Status', 'WWN')
            $result.HotSpareNumbers | Should -Be 2
        }

        It 'gets vStores' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 7; NAME = 'tenant-a'; RUNNINGSTATUS = 1 }) } }

            $result = (Get-DMvStore -WebSession $script:session)[0]

            $result.Name | Should -Be 'tenant-a'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Running Status', 'SAN Free Capacity Quota', 'NAS Free Capacity Quota')
            $result.Description | Should -BeNullOrEmpty
        }

        It 'gets workload types' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'workload-01'; NAME = 'db'; CREATETYPE = 1; BLOCKSIZE = 2 }) } }

            $result = (Get-DMWorkLoadType -WebSession $script:session)[0]

            $result.Id | Should -Be 'workload-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Workload Type', 'Block Size', 'Compression Enabled')
            $result.'Block Size' | Should -Be '16 KB'
        }

        It 'gets workload types by filter' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'workload-01'; NAME = 'db'; CREATETYPE = 1; ENABLECOMPRESS = $true }
                    [pscustomobject]@{ ID = 'workload-02'; NAME = 'archive'; CREATETYPE = 1; ENABLECOMPRESS = $false }
                ) }
            }

            $result = (Get-DMWorkLoadTypebyFilter -WebSession $script:session -Filter 'Compression Enabled' -Keyword enabled)[0]

            $result.Id | Should -Be 'workload-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Workload Type', 'Block Size', 'Compression Enabled')
            $result.'Compression Enabled' | Should -Be 'enabled'
        }
    }
}
}
