BeforeDiscovery {
    $script:getHostsModule = New-Module -Name GetHostsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiators.ps1"

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Private" -Filter 'class-*.ps1' |
            Where-Object Name -ne 'class-OceanStorMappingView.ps1' |
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
            Mock Invoke-DeviceManager {
                param($WebSession, $Method, $Resource)

                switch ($Resource) {
                    'host' { [pscustomobject]@{ data = $script:hostRecords } }
                    'fc_initiator?PARENTID=host-01' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fc-01'; TYPE = 223; PARENTID = 'host-01' }) } }
                    'iscsi_initiator?PARENTID=host-01' { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'iscsi-01'; TYPE = 222; PARENTID = 'host-01' }) } }
                    default { [pscustomobject]@{ data = @() } }
                }
            }

            $result = @(Get-DMhosts -WebSession $script:session)

            $result.Count | Should -Be 2
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result[0].'Parent Id' | Should -Be 'group-01'
            $result[0].initiators.Id | Should -Be @('fc-01', 'iscsi-01')
            $result[1].initiators | Should -BeNullOrEmpty
        }

        It 'gets hosts by id through the filtered endpoint' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @($script:hostRecords[0]) } }

            $result = (Get-DMhostsbyId -WebSession $script:session -HostId 'host-01')[0]

            $result.id | Should -Be 'host-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'gets hosts by name through the filtered endpoint' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @($script:hostRecords[0]) } }

            $result = (Get-DMhostsbyName -WebSession $script:session -Name 'server-a')[0]

            $result.name | Should -Be 'server-a'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'gets hosts by host group id' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = $script:hostRecords } }

            $result = (Get-DMhostsbyHostGroupId -WebSession $script:session -HostGroupId 'group-01')[0]

            $result.id | Should -Be 'host-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-01'
        }

        It 'gets hosts by host group name' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = $script:hostRecords } }

            $result = (Get-DMhostsbyHostGroupName -WebSession $script:session -HostGroupName 'cluster-b')[0]

            $result.id | Should -Be 'host-02'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Health Status', 'Operation System', 'Parent Name')
            $result.'Parent Id' | Should -Be 'group-02'
        }

        It 'gets host groups' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 4; NAME = 'cluster'; TYPE = 0; ISADD2MAPPINGVIEW = 'true' }) } }

            $result = (Get-DMhostGroups -WebSession $script:session)[0]

            $result.Name | Should -Be 'cluster'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Name', 'Is Mapped', 'Host Member Number', 'vStore Name')
            $result.Description | Should -BeNullOrEmpty
        }

        It 'gets FC host links for a host' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'link-01'; HEALTHSTATUS = 1; RUNNINGSTATUS = 10; TARGET_TYPE = 212; TYPE = 255 }) } }

            $result = (Get-DMHostLinks -WebSession $script:session -HostId 'host-01' -InitiatorType FC)[0]

            $result.Id | Should -Be 'link-01'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Host Name', 'Initiator Type', 'Target Type', 'Running Status')
            $result.'Health Status' | Should -Be 'normal'
        }

        It 'gets all fibre channel initiators' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fc-01'; TYPE = 223; RUNNINGSTATUS = 27; vstoreid = 4294967295 }) } }

            $result = (Get-DMHostInitiators -WebSession $script:session -InitatorType FibreChannel)[0]

            $result.Type | Should -Be 'FC Initiator'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
            $result.'vStore ID' | Should -Be 4294967295
        }

        It 'gets free iSCSI initiators' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'iscsi-01'; TYPE = 222; ISFREE = $true; vstoreid = 4294967295 }) } }

            $result = (Get-DMHostInitiators -WebSession $script:session -InitatorType ISCSI -FreeInitiators)[0]

            $result.Type | Should -Be 'ISCSI Initiator'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
            $result.'vStore ID' | Should -Be 4294967295
        }

        It 'returns no initiators when the requested protocol has no data' {
            Mock Invoke-DeviceManager { [pscustomobject]@{ error = [pscustomobject]@{ code = 0 } } }

            $result = @(Get-DMHostInitiators -WebSession $script:session -HostId 'host-fc-only' -InitatorType ISCSI)

            $result | Should -BeNullOrEmpty
        }
    }
}
}
