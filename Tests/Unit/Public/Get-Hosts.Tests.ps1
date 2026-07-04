BeforeDiscovery {
    $script:getHostsModule = New-Module -Name GetHostsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMFilterableProperty.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMValidFilterProperty.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Private" -Filter 'class-*.ps1' |
            Where-Object Name -notin 'class-OceanStorMappingView.ps1', 'class-OceanstorSession.ps1' |
            ForEach-Object { . $_.FullName }

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Public" -Filter 'Get-*.ps1' |
            ForEach-Object { . $_.FullName }

        Export-ModuleMember -Function 'Get-*'
    }

    Import-Module $script:getHostsModule -Force
}

AfterAll {
    Remove-Module -Name GetHostsTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope GetHostsTestModule {
Describe 'Public getter functions' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }
    }
    Describe 'Host getter functions' {
        BeforeEach {
            $script:hostRecords = @(
                [pscustomobject]@{ ID = 'host-01'; NAME = 'server-a'; PARENTTYPE = 14; PARENTID = 'group-01'; PARENTNAME = 'cluster-a'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 21 }
                [pscustomobject]@{ ID = 'host-02'; NAME = 'server-b'; PARENTTYPE = 14; PARENTID = 'group-02'; PARENTNAME = 'cluster-b'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 21 }
            )
        }

        It 'gets hosts' {
            $script:initiatorResources = @()
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                if ($Resource -match 'initiator') {
                    $script:initiatorResources += $Resource
                }

                switch -Wildcard ($Resource) {
                    'host' { [pscustomobject]@{ data = $script:hostRecords } }
                    'host?range=*' { [pscustomobject]@{ data = $script:hostRecords } }
                    'fc_initiator?range=*' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fc-01'; TYPE = 223; PARENTID = 'host-01' }) } }
                    'iscsi_initiator?range=*' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'iscsi-01'; TYPE = 222; PARENTID = 'host-01' }) } }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = @(Get-DMhost -WebSession $script:session)

            $result.Count | Should -Be 2
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result[0].'Parent Id' | Should -Be 'group-01'
            $result[0].initiators.Id | Should -Be @('fc-01', 'iscsi-01')
            $result[1].initiators | Should -BeNullOrEmpty
            @($script:initiatorResources | Where-Object { $_ -match '^fc_initiator\?range=' }).Count | Should -Be 1
            @($script:initiatorResources | Where-Object { $_ -match '^iscsi_initiator\?range=' }).Count | Should -Be 1
        }

        It 'gets a host by Name, delegating to the filtered endpoint' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -like 'host?filter=NAME::server-a*') {
                    $script:nameResource = $Resource
                    return [pscustomobject]@{ data = @($script:hostRecords[0]) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMhost -WebSession $script:session -Name 'server-a')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be 'host-01'
            $script:nameResource | Should -BeLike 'host?filter=NAME::server-a*'
        }

        It 'gets a host by Id, delegating to the filtered endpoint' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -like 'host?filter=ID::host-01*') {
                    $script:idResource = $Resource
                    return [pscustomobject]@{ data = @($script:hostRecords[0]) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMhost -WebSession $script:session -Id 'host-01')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be 'host-01'
            $script:idResource | Should -BeLike 'host?filter=ID::host-01*'
        }

        It 'rejects supplying both Name and Id for Get-DMhost' {
            { Get-DMhost -WebSession $script:session -Name 'server-a' -Id 'host-01' } | Should -Throw '*parameter set*'
        }

        It 'gets hosts directly by -Filter/-Value using an exact server-side query' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -like 'host?filter=NAME::server-a*') {
                    $script:directFilterResource = $Resource
                    return [pscustomobject]@{ data = @($script:hostRecords[0]) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMhost -WebSession $script:session -Filter Name -Value 'server-a')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be 'host-01'
            $script:directFilterResource | Should -BeLike 'host?filter=NAME::server-a*'
        }

        It 'gets hosts directly by -HostGroupId without resolving through Get-DMhostGroup' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -eq 'host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=group-01') {
                    return [pscustomobject]@{ data = @($script:hostRecords[0]) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMhost -WebSession $script:session -HostGroupId 'group-01')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be 'host-01'
        }

        It 'gets hosts directly by -HostGroupName, resolving the group first' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                switch -Wildcard ($Resource) {
                    'host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=2*' { [pscustomobject]@{ data = @($script:hostRecords[1]) }; break }
                    'hostgroup*' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = '2'; NAME = 'cluster-b'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }) }; break }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = @(Get-DMhost -WebSession $script:session -HostGroupName 'cluster-b')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be 'host-02'
        }

        It 'gets hosts directly by piped -HostGroup object' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -eq 'host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=group-01') {
                    return [pscustomobject]@{ data = @($script:hostRecords[0]) }
                }
                [pscustomobject]@{ data = @() }
            }

            $hostGroup = [pscustomobject]@{ Id = 'group-01'; Name = 'cluster-a' }
            $result = @($hostGroup | Get-DMhost -WebSession $script:session)

            $result.Count | Should -Be 1
            $result[0].id | Should -Be 'host-01'
        }

        It 'exposes completion metadata for -Name, sourced from a live host sample' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                switch -Wildcard ($Resource) {
                    'host' { [pscustomobject]@{ data = $script:hostRecords } }
                    'host?range=*' { [pscustomobject]@{ data = $script:hostRecords } }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $command = Get-Command Get-DMhost
            @($command.Parameters['Name'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
                Should -BeGreaterThan 0 -Because 'Get-DMhost -Name should support tab completion'

            $completer = ($command.Parameters['Name'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] })[0].ScriptBlock
            $fakeBoundParameters = @{ WebSession = $script:session }
            $candidates = @(& $completer 'Get-DMhost' 'Name' '' $null $fakeBoundParameters)

            $candidates | Should -Contain 'server-a'
            $candidates | Should -Contain 'server-b'
        }

        It 'throws a descriptive error when the API reports a failure retrieving hosts' {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 1077939726; description = 'session expired' } }
            }

            { Get-DMhost -WebSession $script:session } |
                Should -Throw '*1077939726*session expired*call Connect-deviceManager again*'
        }

        It 'gets hosts by id through the filtered endpoint' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @($script:hostRecords[0]) } }

            $result = (Get-DMhostbyId -WebSession $script:session -HostId 'host-01')[0]

            $result.id | Should -Be 'host-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'gets hosts by name through the filtered endpoint' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @($script:hostRecords[0]) } }

            $result = (Get-DMhostbyName -WebSession $script:session -Name 'server-a')[0]

            $result.name | Should -Be 'server-a'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'rejects a Filter that is not a real host property, before making any REST call' {
            { Get-DMhostbyFilter -WebSession $script:session -Filter 'Bogus' -Keyword 'x' } |
                Should -Throw "*Invalid Filter 'Bogus'*"

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'filters hosts by a known field through an exact server-side filter' {
            $script:capturedResource = $null
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -like 'host?filter=ID::host-01*') {
                    $script:capturedResource = $Resource
                    return [pscustomobject]@{ data = @($script:hostRecords[0]) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = (Get-DMhostbyFilter -WebSession $script:session -Filter 'Id' -Keyword 'host-01')[0]

            $result.id | Should -Be 'host-01'
            $script:capturedResource | Should -BeLike 'host?filter=ID::host-01*'
        }

        It 'filters hosts by a known field through a fuzzy server-side hint when Keyword has a trailing wildcard' {
            $script:capturedResource = $null
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -like 'host?filter=NAME:server-a*') {
                    $script:capturedResource = $Resource
                    return [pscustomobject]@{ data = $script:hostRecords }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMhostbyFilter -WebSession $script:session -Filter 'Name' -Keyword 'server-a*')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be 'host-01'
            $script:capturedResource | Should -BeLike 'host?filter=NAME:server-a*'
        }

        It 'exposes completion metadata for -Filter, sourced from a live host sample' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @($script:hostRecords[0]) } }

            $command = Get-Command Get-DMhostbyFilter
            @($command.Parameters['Filter'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
                Should -BeGreaterThan 0 -Because 'Get-DMhostbyFilter -Filter should support tab completion'

            $completer = ($command.Parameters['Filter'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] })[0].ScriptBlock
            $fakeBoundParameters = @{ WebSession = $script:session }
            $candidates = @(& $completer 'Get-DMhostbyFilter' 'Filter' '' $null $fakeBoundParameters)

            $candidates | Should -Contain 'Name'
            $candidates | Should -Contain 'Health Status'
            $candidates | Should -Not -Contain 'Session'
        }

        It 'falls back to a client-side filter for an unmapped field' {
            $script:capturedResource = $null
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -like 'host?range=*') {
                    $script:capturedResource = $Resource
                    return [pscustomobject]@{ data = $script:hostRecords }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = @(Get-DMhostbyFilter -WebSession $script:session -Filter 'Parent Name' -Keyword 'cluster-b')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be 'host-02'
            $script:capturedResource | Should -BeLike 'host?range=*'
        }

        It 'gets hosts by host group id' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                if ($Resource -eq 'host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=group-01') {
                    return [pscustomobject]@{ data = @($script:hostRecords[0]) }
                }
                [pscustomobject]@{ data = @() }
            }

            $result = (Get-DMhostbyHostGroup -WebSession $script:session -HostGroupId 'group-01')[0]

            $result.id | Should -Be 'host-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'gets hosts by host group name' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                switch -Wildcard ($Resource) {
                    'host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=2*' { [pscustomobject]@{ data = @($script:hostRecords[1]) }; break }
                    'hostgroup*' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 2; NAME = 'cluster-b'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }) }; break }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = (Get-DMhostbyHostGroup -WebSession $script:session -HostGroupName 'cluster-b')[0]

            $result.id | Should -Be 'host-02'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-02'
        }

        It 'gets host groups' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 4; NAME = 'cluster'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }) } }

            $result = (Get-DMhostGroup -WebSession $script:session)[0]

            $result.Name | Should -Be 'cluster'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Is Mapped', 'Host Member Number', 'vStore Name')
            $result.Description | Should -BeNullOrEmpty
        }

        It 'gets a host group by positional Name using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:hostGroupNameResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 4; NAME = 'cluster'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }) }
            }

            $result = (Get-DMhostGroup -WebSession $script:session 'cluster')[0]

            $result.Name | Should -Be 'cluster'
            $script:hostGroupNameResource | Should -BeLike 'hostgroup?filter=NAME::cluster*'
        }

        It 'gets a host group by Id using an exact server-side filter' {
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                $script:hostGroupIdResource = $Resource
                [pscustomobject]@{ data = @([pscustomobject]@{ ID = 4; NAME = 'cluster'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }) }
            }

            $result = (Get-DMhostGroup -WebSession $script:session -Id 4)[0]

            $result.Id | Should -Be 4
            $script:hostGroupIdResource | Should -BeLike 'hostgroup?filter=ID::4*'
        }

        It 'rejects supplying both Name and Id for Get-DMhostGroup' {
            { Get-DMhostGroup -WebSession $script:session -Name 'cluster' -Id 4 } | Should -Throw '*parameter set*'
        }

        It 'gets FC host links for a host' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'link-01'; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; TARGET_TYPE = 212; TYPE = 255 }) } }

            $result = (Get-DMHostLink -WebSession $script:session -HostId 'host-01' -InitiatorType FC)[0]

            $result.Id | Should -Be 'link-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Host Name', 'Initiator Type', 'Target Type', 'Running Status')
            $result.'Health Status' | Should -Be 'normal'
        }

        It 'gets all fibre channel initiators' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fc-01'; TYPE = 223; RUNNINGSTATUS = 27; vstoreid = 4294967295 }) } }

            $result = (Get-DMHostInitiator -WebSession $script:session -InitiatorType FibreChannel)[0]

            $result.Type | Should -Be 'FC Initiator'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
            $result.'vStore ID' | Should -Be 4294967295
        }

        It 'gets free iSCSI initiators' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'iscsi-01'; TYPE = 222; ISFREE = $true; vstoreid = 4294967295 }) } }

            $result = (Get-DMHostInitiator -WebSession $script:session -InitiatorType ISCSI -FreeInitiators)[0]

            $result.Type | Should -Be 'ISCSI Initiator'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
            $result.'vStore ID' | Should -Be 4294967295
        }

        It 'returns no initiators when the requested protocol has no data' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ error = [pscustomobject]@{ code = 0 } } }

            $result = @(Get-DMHostInitiator -WebSession $script:session -HostId 'host-fc-only' -InitiatorType ISCSI)

            $result | Should -BeNullOrEmpty
        }
    }

    Describe 'Host getter deprecation warnings' {
        BeforeEach {
            $script:hostRecords = @(
                [pscustomobject]@{ ID = 'host-01'; NAME = 'server-a'; PARENTTYPE = 14; PARENTID = 'group-01'; PARENTNAME = 'cluster-a'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 21 }
                [pscustomobject]@{ ID = 'host-02'; NAME = 'server-b'; PARENTTYPE = 14; PARENTID = 'group-02'; PARENTNAME = 'cluster-b'; HEALTHSTATUS = 1; RUNNINGSTATUS = 1; TYPE = 21 }
            )
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)
                switch -Wildcard ($Resource) {
                    'host?filter=NAME::server-a*' { [pscustomobject]@{ data = @($script:hostRecords[0]) }; break }
                    'host?filter=ID::host-01*' { [pscustomobject]@{ data = @($script:hostRecords[0]) }; break }
                    default { [pscustomobject]@{ data = @() } }
                }
            }
        }

        It 'Get-DMhostbyFilter warns about deprecation' {
            Get-DMhostbyFilter -WebSession $script:session -Filter 'Name' -Keyword 'server-a' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings.Count | Should -Be 1
            $warnings[0] | Should -Match 'deprecated'
        }

        It 'Get-DMhostbyName warns about deprecation' {
            Get-DMhostbyName -WebSession $script:session -Name 'server-a' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings.Count | Should -Be 1
            $warnings[0] | Should -Match 'deprecated'
        }

        It 'Get-DMhostbyId warns about deprecation' {
            Get-DMhostbyId -WebSession $script:session -hostId 'host-01' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings.Count | Should -Be 1
            $warnings[0] | Should -Match 'deprecated'
        }
    }
}
}
