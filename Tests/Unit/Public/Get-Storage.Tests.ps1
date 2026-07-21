BeforeDiscovery {
    $script:getStorageModule = New-Module -Name GetStorageTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMFilterableProperty.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMValidFilterProperty.ps1"
        . "$testRoot\..\Support\DMResponseFixtures.ps1"

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

        It 'gets a file system by positional Name using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:fsResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = '0'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27 }) }
            }

            $result = @(Get-DMFileSystem -WebSession $script:session 'documents')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'documents'
            $script:fsResource | Should -BeLike 'filesystem?filter=NAME::documents*'
        }

        It 'gets file systems by Name using a fuzzy server-side hint for a wildcard keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:fsResource = $Resource
                if ($Resource -like 'filesystem?filter=NAME:doc*') {
                    return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fs-01'; NAME = 'documents'; SECTORSIZE = 512; CAPACITY = 2097152; ALLOCCAPACITY = '0'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27 }) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMFileSystem -WebSession $script:session -Name 'doc*')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'documents'
            $script:fsResource | Should -BeLike 'filesystem?filter=NAME:doc*'
        }

        It 'gets LUN groups' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'luns'; GROUPTYPE = 0; CAPCITY = 1GB }) } }

            $result = (Get-DMlunGroup -WebSession $script:session)[0]

            $result.Id | Should -Be 12
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'LunGroup Capacity', 'Is Mapped', 'Luns Members number')
            $result.Description | Should -BeNullOrEmpty
        }

        It 'gets a LUN group by Id using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:lunGroupIdResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'luns'; GROUPTYPE = 0; CAPCITY = 1GB }) }
            }

            $result = (Get-DMlunGroup -WebSession $script:session -Id 12)[0]

            $result.Id | Should -Be 12
            $script:lunGroupIdResource | Should -BeLike 'lungroup?filter=ID::12*'
        }

        It 'rejects an unknown LUN group Id' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }

            @(Get-DMlunGroup -WebSession $script:session -Id 'missing') | Should -BeNullOrEmpty
        }

        It 'rejects supplying both Name and Id for Get-DMlunGroup' {
            { Get-DMlunGroup -WebSession $script:session -Name 'luns' -Id 12 } | Should -Throw '*parameter set*'
        }

        It 'retrieves LUN objects associated with a LUN group through its method' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch -Wildcard ($Resource) {
                    'lungroup/12'  { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '["lun-02"]' } }; break }
                    'lungroup*'    { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'luns'; GROUPTYPE = 0; CAPCITY = 1GB }) }; break }
                    'lun?filter=ID::lun-02*' { [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -Name 'archive') }; break }
                    'lun'          { throw 'GetLuns should not materialize the full LUN inventory.' }
                    default        { [pscustomobject]@{ data = @() } }
                }
            }

            $lunGroup = (Get-DMlunGroup -WebSession $script:session)[0]
            $result = @($lunGroup.GetLuns())

            $result.Name | Should -Be @('archive')
            $result[0].GetType().Name | Should -Be 'OceanstorLunv6'
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size (GB)', 'WWN')
        }

        It 'returns no LUNs for an empty LUN group association list' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch -Wildcard ($Resource) {
                    'lungroup/12' { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '[]' } }; break }
                    'lungroup*'   { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 12; NAME = 'empty-luns'; GROUPTYPE = 0; CAPCITY = 0 }) }; break }
                }
            }

            $lunGroup = (Get-DMlunGroup -WebSession $script:session)[0]
            $result = @($lunGroup.GetLuns())

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-DeviceManager -ParameterFilter { $Resource -eq 'lun' } -Times 0 -Exactly
        }

        It 'gets version 6 LUNs' {
            Mock Invoke-DeviceManager { New-DMFixtureSuccessResponse -Data @(New-DMFixtureLun -Id 'lun-01' -Name 'data-lun' -Wwn 'wwn-01') }

            $result = Get-DMlun -WebSession $script:session

            $result[0].Id | Should -Be 'lun-01'
            $result[0].GetType().Name | Should -Be 'OceanstorLunv6'
        }

        It 'gets a LUN by positional Keyword, matching Name first' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:keywordResource = $Resource
                if ($Resource -like (New-DMExactFilterResource -Resource 'lun' -Property 'NAME' -Value 'finance')) {
                    return New-DMFixtureSuccessResponse -Data @(New-DMFixtureLun -Id 'lun-01' -Name 'finance')
                }
                New-DMFixtureEmptyResponse
            }

            $result = @(Get-DMlun -WebSession $script:session 'finance')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-01'
            $script:keywordResource | Should -BeLike (New-DMExactFilterResource -Resource 'lun' -Property 'NAME' -Value 'finance')
        }

        It 'falls back to WWN when Keyword matches no LUN by Name' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:keywordResources += $Resource
                if ($Resource -like (New-DMExactFilterResource -Resource 'lun' -Property 'WWN' -Value '658be72100f6793b6bb9512e000000e1')) {
                    return New-DMFixtureSuccessResponse -Data @(New-DMFixtureLun -Id 'lun-02' -Wwn '658be72100f6793b6bb9512e000000e1')
                }
                New-DMFixtureEmptyResponse
            }
            $script:keywordResources = @()

            $result = @(Get-DMlun -WebSession $script:session '658be72100f6793b6bb9512e000000e1')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-02'
            $script:keywordResources[0] | Should -BeLike (New-DMExactFilterResource -Resource 'lun' -Property 'NAME' -Value '658be72100f6793b6bb9512e000000e1')
            $script:keywordResources[1] | Should -BeLike (New-DMExactFilterResource -Resource 'lun' -Property 'WWN' -Value '658be72100f6793b6bb9512e000000e1')
        }

        It 'gets a LUN by Id using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:idResource = $Resource
                New-DMFixtureSuccessResponse -Data @(New-DMFixtureLun -Id 'lun-01' -Name 'finance')
            }

            $result = @(Get-DMlun -WebSession $script:session -Id 'lun-01')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-01'
            $script:idResource | Should -BeLike (New-DMExactFilterResource -Resource 'lun' -Property 'ID' -Value 'lun-01')
        }

        It 'rejects supplying both Keyword and Id for Get-DMlun' {
            { Get-DMlun -WebSession $script:session -Keyword 'finance' -Id 'lun-01' } | Should -Throw '*parameter set*'
        }

        It 'supports a wildcard Keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:keywordResource = $Resource
                if ($Resource -like (New-DMFuzzyFilterResource -Resource 'lun' -Property 'NAME' -Value 'fin')) {
                    return New-DMFixtureSuccessResponse -Data @(New-DMFixtureLun -Id 'lun-01' -Name 'finance')
                }
                New-DMFixtureEmptyResponse
            }

            $result = @(Get-DMlun -WebSession $script:session -Keyword 'fin*')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-01'
            $script:keywordResource | Should -BeLike (New-DMFuzzyFilterResource -Resource 'lun' -Property 'NAME' -Value 'fin')
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
                    'lun?filter=NAME::data-lun*' { [pscustomobject]@{ data = @(New-TestLun) } }
                    'lun' { throw 'Get-DMLunSnapshot -LunName should not materialize the full LUN inventory.' }
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

        It 'gets a LUN snapshot by positional Name using a server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:snapshotNameResource = $Resource
                [pscustomobject]@{ data = @(New-TestLunSnapshot) }
            }

            $result = @(Get-DMLunSnapshot -WebSession $script:session 'before-patch')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'before-patch'
            $script:snapshotNameResource | Should -BeLike 'snapshot?filter=NAME::before-patch*'
        }

        It 'gets a LUN snapshot by Id using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:snapshotIdResource = $Resource
                [pscustomobject]@{ data = @(New-TestLunSnapshot) }
            }

            $result = @(Get-DMLunSnapshot -WebSession $script:session -Id 'snap-01')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'snap-01'
            $script:snapshotIdResource | Should -BeLike 'snapshot?filter=ID::snap-01*'
        }

        It 'rejects supplying both Name and Id for Get-DMLunSnapshot' {
            { Get-DMLunSnapshot -WebSession $script:session -Name 'before-patch' -Id 'snap-01' } |
                Should -Throw '*parameter set*'
        }

        It 'rejects a Filter that is not a real LUN property, before making any REST call' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                [pscustomobject]@{ data = @(New-TestLun) }
            }

            { Get-DMLunbyFilter -WebSession $script:session -Filter 'Bogus' -Keyword 'x' } |
                Should -Throw "*Invalid Filter 'Bogus'*"

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'gets LUNs by filter using an exact server-side query for known fields' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:filterResource = $Resource
                [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') }
            }

            $result = (Get-DMLunbyFilter -WebSession $script:session -Filter Name -Keyword finance)[0]

            $result.Id | Should -Be 'lun-01'
            $script:filterResource | Should -BeLike 'lun?filter=NAME::finance*'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size (GB)', 'WWN')
            $result.'Allocation Type' | Should -Be 'Thin'
        }

        It 'gets LUNs by filter using a fuzzy server-side hint for a wildcard keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:filterResource = $Resource
                if ($Resource -like 'lun?filter=NAME:fin*') {
                    return [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMLunbyFilter -WebSession $script:session -Filter Name -Keyword 'fin*')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-01'
            $script:filterResource | Should -BeLike 'lun?filter=NAME:fin*'
        }

        It 'exposes completion metadata for -Filter, sourced from a live LUN sample' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @(New-TestLun) } }

            $command = Get-Command Get-DMLunbyFilter
            @($command.Parameters['Filter'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
                Should -BeGreaterThan 0 -Because 'Get-DMLunbyFilter -Filter should support tab completion'

            $completer = ($command.Parameters['Filter'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] })[0].ScriptBlock
            $fakeBoundParameters = @{ WebSession = $script:session }
            $candidates = @(& $completer 'Get-DMLunbyFilter' 'Filter' '' $null $fakeBoundParameters)

            $candidates | Should -Contain 'Name'
            $candidates | Should -Contain 'WWN'
            $candidates | Should -Not -Contain 'Session'
        }

        It 'gets LUNs by filter using client-side exact match for unmapped properties' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:filterResource = $Resource
                [pscustomobject]@{ data = @((New-TestLun -Id 'lun-01' -Name 'finance'), (New-TestLun -Id 'lun-02' -Name 'archive')) }
            }

            $result = @(Get-DMLunbyFilter -WebSession $script:session -Filter 'Allocation Type' -Keyword 'Thin')

            $script:filterResource | Should -BeLike 'lun?range=*'
            $result.Count | Should -Be 2
        }

        It 'gets a LUN by WWN using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:wwnResource = $Resource
                [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -WWN 'wwn-b') }
            }

            $result = (Get-DMlunByWWN -WebSession $script:session -WWN 'wwn-b')[0]

            $result.Id | Should -Be 'lun-02'
            $script:wwnResource | Should -BeLike 'lun?filter=WWN::wwn-b*'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size (GB)', 'WWN')
            $result.'Allocation Type' | Should -Be 'Thin'
        }

        It 'gets a LUN by WWN using a fuzzy server-side hint for a wildcard keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:wwnResource = $Resource
                if ($Resource -like 'lun?filter=WWN:wwn-*') {
                    return [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -WWN 'wwn-b') }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMlunByWWN -WebSession $script:session -WWN 'wwn-*')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-02'
            $script:wwnResource | Should -BeLike 'lun?filter=WWN:wwn-*'
        }

        It 'gets a LUN by name using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:nameResource = $Resource
                [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') }
            }

            $result = (Get-DMlunByName -WebSession $script:session -Name 'finance')[0]

            $result.Id | Should -Be 'lun-01'
            $script:nameResource | Should -BeLike 'lun?filter=NAME::finance*'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Lun Size (GB)', 'WWN')
            $result.'Allocation Type' | Should -Be 'Thin'
        }

        It 'gets LUNs by name using a fuzzy server-side hint for a wildcard keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:nameResource = $Resource
                if ($Resource -like 'lun?filter=NAME:fin*') {
                    return [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMlunByName -WebSession $script:session -Name 'fin*')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-01'
            $script:nameResource | Should -BeLike 'lun?filter=NAME:fin*'
        }

        It 'gets a LUN directly by -Name using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:directNameResource = $Resource
                [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') }
            }

            $result = (Get-DMlun -WebSession $script:session -Name 'finance')[0]

            $result.Id | Should -Be 'lun-01'
            $script:directNameResource | Should -BeLike 'lun?filter=NAME::finance*'
        }

        It 'gets a LUN directly by -WWN using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:directWwnResource = $Resource
                [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -WWN 'wwn-b') }
            }

            $result = (Get-DMlun -WebSession $script:session -WWN 'wwn-b')[0]

            $result.Id | Should -Be 'lun-02'
            $script:directWwnResource | Should -BeLike 'lun?filter=WWN::wwn-b*'
        }

        It 'gets LUNs directly by -Filter/-Value using an exact server-side query' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:directFilterResource = $Resource
                [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') }
            }

            $result = (Get-DMlun -WebSession $script:session -Filter Name -Value finance)[0]

            $result.Id | Should -Be 'lun-01'
            $script:directFilterResource | Should -BeLike 'lun?filter=NAME::finance*'
        }

        It 'gets LUNs directly by -LunGroupId without resolving through Get-DMlunGroup' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                switch -Wildcard ($Resource) {
                    'lungroup/lg-01' { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '["lun-02"]' } }; break }
                    'lun?filter=ID::lun-02*' { [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -Name 'archive') }; break }
                    'lun' { throw 'Get-DMlun -LunGroupId should not materialize the full LUN inventory.' }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = @(Get-DMlun -WebSession $script:session -LunGroupId 'lg-01')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-02'
        }

        It 'gets LUNs directly by -LunGroupName, resolving the group first' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                switch -Wildcard ($Resource) {
                    'lungroup/1' { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '["lun-02"]' } }; break }
                    'lungroup?filter=NAME::production-luns*' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = '1'; NAME = 'production-luns'; GROUPTYPE = 0; CAPCITY = 1GB }) }; break }
                    'lungroup' { throw 'Get-DMlun -LunGroupName should not materialize the full LUN group inventory.' }
                    'lun?filter=ID::lun-02*' { [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -Name 'archive') }; break }
                    'lun' { throw 'Get-DMlun -LunGroupName should not materialize the full LUN inventory.' }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = @(Get-DMlun -WebSession $script:session -LunGroupName 'production-luns')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-02'
        }

        It 'gets LUNs directly by piped -LunGroup object' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                switch -Wildcard ($Resource) {
                    'lungroup/lg-01' { [pscustomobject]@{ data = [pscustomobject]@{ ASSOCIATELUNIDLIST = '["lun-02"]' } }; break }
                    'lun?filter=ID::lun-02*' { [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -Name 'archive') }; break }
                    'lun' { throw 'Piped Get-DMlun -LunGroup should not materialize the full LUN inventory.' }
                    default { [pscustomobject]@{ data = @() } }
                }
            }
            $lunGroup = [pscustomobject]@{ Id = 'lg-01'; Name = 'production-luns' }

            $result = @($lunGroup | Get-DMlun -WebSession $script:session)

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'lun-02'
        }

        It 'rejects supplying both -Name and -Id for Get-DMlun' {
            { Get-DMlun -WebSession $script:session -Name 'finance' -Id 'lun-01' } | Should -Throw '*parameter set*'
        }

        It 'Get-DMLunbyFilter warns about deprecation' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') } }

            Get-DMLunbyFilter -WebSession $script:session -Filter Name -Keyword finance -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings.Count | Should -Be 1
            $warnings[0] | Should -Match 'deprecated'
        }

        It 'Get-DMlunByWWN warns about deprecation' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @(New-TestLun -Id 'lun-02' -WWN 'wwn-b') } }

            Get-DMlunByWWN -WebSession $script:session -WWN 'wwn-b' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings.Count | Should -Be 1
            $warnings[0] | Should -Match 'deprecated'
        }

        It 'Get-DMlunByName warns about deprecation' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @(New-TestLun -Id 'lun-01' -Name 'finance') } }

            Get-DMlunByName -WebSession $script:session -Name 'finance' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings.Count | Should -Be 1
            $warnings[0] | Should -Match 'deprecated'
        }

        It 'gets NFS file clients' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'client-01'; NAME = '10.0.0.0/24'; ACCESSVAL = 1; CHARSET = 0 }) } }

            $result = (Get-DMnfsFileClient -WebSession $script:session)[0]

            $result.Id | Should -Be 'client-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'NFS Share Name', 'Access Permission', 'WriteMode')
            $result.'Charset Encoding' | Should -Be 'UTF-8'
        }

        It 'gets an NFS file client by positional Name using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:clientResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'client-01'; NAME = '10.0.0.0/24'; ACCESSVAL = 1; CHARSET = 0 }) }
            }

            $result = @(Get-DMnfsFileClient -WebSession $script:session '10.0.0.0/24')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be '10.0.0.0/24'
            $script:clientResource | Should -BeLike 'NFS_SHARE_AUTH_CLIENT?filter=NAME::10.0.0.0%2F24*'
        }

        It 'gets NFS file clients by Name using a fuzzy server-side hint for a wildcard keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:clientResource = $Resource
                if ($Resource -like 'NFS_SHARE_AUTH_CLIENT?filter=NAME:10.0.0*') {
                    return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'client-01'; NAME = '10.0.0.0/24'; ACCESSVAL = 1; CHARSET = 0 }) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMnfsFileClient -WebSession $script:session -Name '10.0.0*')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be '10.0.0.0/24'
            $script:clientResource | Should -BeLike 'NFS_SHARE_AUTH_CLIENT?filter=NAME:10.0.0*'
        }

        It 'gets CIFS shares' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'cifs-01'; NAME = 'share'; subType = 0 }) } }

            $result = (Get-DMShare -WebSession $script:session -ShareType CIFS)[0]

            $result.Id | Should -Be 'cifs-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Share Path', 'FileSystem ID', 'vStore Name')
            $result.'Sub Type' | Should -Be 'normal'
        }

        It 'gets a CIFS share by positional Name using an exact server-side filter on NAME' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:cifsResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'cifs-01'; NAME = 'finance'; subType = 0 }) }
            }

            $result = @(Get-DMShare -WebSession $script:session 'finance' -ShareType CIFS)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'finance'
            $script:cifsResource | Should -BeLike 'CIFSHARE?filter=NAME::finance*'
        }

        It 'gets CIFS shares by Name using a fuzzy server-side hint for a wildcard keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:cifsResource = $Resource
                if ($Resource -like 'CIFSHARE?filter=NAME:fin*') {
                    return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'cifs-01'; NAME = 'finance'; subType = 0 }) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMShare -WebSession $script:session -Name 'fin*' -ShareType CIFS)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'finance'
            $script:cifsResource | Should -BeLike 'CIFSHARE?filter=NAME:fin*'
        }

        It 'gets NFS shares' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'nfs-01'; NAME = 'export'; CHARACTERENCODING = 0 }) } }

            $result = (Get-DMShare -WebSession $script:session -ShareType NFS)[0]

            $result.Id | Should -Be 'nfs-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Share Path', 'FileSystem ID', 'vStore Name')
            $result.'Character Enconding' | Should -Be 'UTF-8'
        }

        It 'gets an NFS share by Name matching Share Path server-side, since NFSHARE NAME filtering is unsupported' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:nfsResource = $Resource
                if ($Resource -like 'NFSHARE?filter=SHAREPATH:documents*') {
                    return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'nfs-01'; NAME = ''; SHAREPATH = '/documents/'; CHARACTERENCODING = 0 }) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMShare -WebSession $script:session -Name '*documents*' -ShareType NFS)

            $result.Count | Should -Be 1
            $result[0].'Share Path' | Should -Be '/documents/'
            $script:nfsResource | Should -BeLike 'NFSHARE?filter=SHAREPATH:documents*'
        }

        It 'never requests an exact double-colon filter for NFS shares, since SHAREPATH is fuzzy-match only' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:nfsResource = $Resource
                if ($Resource -like 'NFSHARE?filter=SHAREPATH:%2Fdocuments%2F*') {
                    return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'nfs-01'; NAME = ''; SHAREPATH = '/documents/'; CHARACTERENCODING = 0 }) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMShare -WebSession $script:session -Name '/documents/' -ShareType NFS)

            $result.Count | Should -Be 1
            $script:nfsResource | Should -BeLike 'NFSHARE?filter=SHAREPATH:%2Fdocuments%2F*'
        }

        It 'gets storage pools' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'pool-01'; NAME = 'pool'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; DATASPACE = 2097152; USERTOTALCAPACITY = 4194304 }) } }

            $result = (Get-DMstoragePool -WebSession $script:session)[0]

            $result.id | Should -Be 'pool-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Running Status', 'Total Capacity (GB)', 'Free Capacity (GB)')
            # sectors * 512 / 1GB: 2097152 -> 1 GB
            $result.'Available For LUN (GB)' | Should -Be 1
        }

        It 'gets a storage pool by positional Name using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:poolResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'pool-01'; NAME = 'performance'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; DATASPACE = (512 * 1GB) }) }
            }

            $result = @(Get-DMstoragePool -WebSession $script:session 'performance')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'performance'
            $script:poolResource | Should -Be 'storagepool?filter=NAME::performance'
        }

        It 'gets a storage pool by Id using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:poolResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = '3'; NAME = 'performance'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; DATASPACE = (512 * 1GB) }) }
            }

            $result = @(Get-DMstoragePool -WebSession $script:session -Id '3')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be '3'
            $script:poolResource | Should -Be 'storagepool?filter=ID::3'
        }

        It 'gets storage pools by Name using a fuzzy server-side hint for a wildcard keyword' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:poolResource = $Resource
                if ($Resource -eq 'storagepool?filter=NAME:perf') {
                    return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'pool-01'; NAME = 'performance'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27; DATASPACE = (512 * 1GB) }) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMstoragePool -WebSession $script:session -Name 'perf*')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'performance'
            $script:poolResource | Should -Be 'storagepool?filter=NAME:perf'
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

            $result = (Get-DMWorkLoadType -WebSession $script:session -Filter 'Compression Enabled' -Keyword enabled)[0]

            $result.Id | Should -Be 'workload-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Workload Type', 'Block Size', 'Compression Enabled')
            $result.'Compression Enabled' | Should -Be 'enabled'
        }

        It 'gets a workload type by Id (client-side, no server-side ID filter)' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:workloadResource = $Resource
                [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'workload-01'; NAME = 'db'; CREATETYPE = 1 }
                    [pscustomobject]@{ ID = 'workload-02'; NAME = 'archive'; CREATETYPE = 1 }
                ) }
            }

            $result = @(Get-DMWorkLoadType -WebSession $script:session -Id 'workload-02')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'workload-02'
            # ID is not a supported workload_type filter field, so no filter is sent.
            $script:workloadResource | Should -Be 'workload_type?isDetailInfo=true'
        }

        It 'gets workload types by Name using a server-side filter hint' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:workloadResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'workload-01'; NAME = 'db'; CREATETYPE = 1 }) }
            }

            $result = (Get-DMWorkLoadType -WebSession $script:session -Name 'db')[0]

            $result.Id | Should -Be 'workload-01'
            $script:workloadResource | Should -BeLike 'workload_type?isDetailInfo=true&filter=NAME::db*'
        }

        It 'gets workload types by CompressionEnabled using an unconfirmed server-side filter hint' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:workloadResource = $Resource
                [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'workload-01'; NAME = 'db'; CREATETYPE = 1; ENABLECOMPRESS = $true }
                    [pscustomobject]@{ ID = 'workload-02'; NAME = 'archive'; CREATETYPE = 1; ENABLECOMPRESS = $false }
                ) }
            }

            $result = @(Get-DMWorkLoadType -WebSession $script:session -CompressionEnabled $true)

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'workload-01'
            $script:workloadResource | Should -BeLike 'workload_type?isDetailInfo=true&filter=ENABLECOMPRESS::true*'
        }

        It 'gets workload types by DedupeEnabled using an unconfirmed server-side filter hint' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:workloadResource = $Resource
                [pscustomobject]@{ data = @(
                    [pscustomobject]@{ ID = 'workload-01'; NAME = 'db'; CREATETYPE = 1; ENABLEDEDUP = $false }
                    [pscustomobject]@{ ID = 'workload-02'; NAME = 'archive'; CREATETYPE = 1; ENABLEDEDUP = $true }
                ) }
            }

            $result = @(Get-DMWorkLoadType -WebSession $script:session -DedupeEnabled $false)

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'workload-01'
            $script:workloadResource | Should -BeLike 'workload_type?isDetailInfo=true&filter=ENABLEDEDUP::false*'
        }
    }
}
}
