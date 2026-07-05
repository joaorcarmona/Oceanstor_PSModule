BeforeDiscovery {
    $script:drReadModule = New-Module -Name DrReadOnlyTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [int]$TimeoutSec,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorRemoteDevice.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorRemoteLun.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHyperMetroConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMRemoteDevice.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMRemoteLun.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMReplicationPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMReplicationConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMHyperMetroDomain.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMHyperMetroPair.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMHyperMetroConsistencyGroup.ps1"

        Export-ModuleMember -Function 'Get-DMRemoteDevice', 'Get-DMRemoteLun',
            'Get-DMReplicationPair', 'Get-DMReplicationConsistencyGroup',
            'Get-DMHyperMetroDomain', 'Get-DMHyperMetroPair',
            'Get-DMHyperMetroConsistencyGroup'
    }

    Import-Module $script:drReadModule -Force
}

AfterAll {
    Remove-Module -Name DrReadOnlyTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope DrReadOnlyTestModule {
Describe 'Remote replication and HyperMetro read-only getters' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:resource = $null
        $script:method = $null
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $data = switch -Wildcard ($Resource) {
                'remote_device/*' {
                    [pscustomobject]@{ ID = '0'; NAME = 'remote-a'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '10'; ARRAYTYPE = '1'; SN = 'SN001'; LINKNUM = '2' }
                    break
                }
                'remote_device*' {
                    @(
                        [pscustomobject]@{ ID = '0'; NAME = 'remote-a'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '10'; ARRAYTYPE = '1'; SN = 'SN001' }
                        [pscustomobject]@{ ID = '1'; NAME = 'remote-b'; HEALTHSTATUS = '2'; RUNNINGSTATUS = '11'; ARRAYTYPE = '1'; SN = 'SN002' }
                    )
                    break
                }
                'remote_lun*' {
                    @(
                        [pscustomobject]@{ ID = '0;2;INVALID;INVALID;INVALID'; NAME = 'remote-lun-a'; LUNID = '2'; LUNWWN = 'wwn-a'; DEVICEID = '0'; DEVICESN = 'SN001'; HEALTHSTATUS = '1'; ARRAYTYPE = '1'; CAPACITYBYTE = '1073741824' }
                        [pscustomobject]@{ ID = '0;3;INVALID;INVALID;INVALID'; NAME = 'remote-lun-b'; LUNID = '3'; LUNWWN = 'wwn-b'; DEVICEID = '0'; DEVICESN = 'SN001'; HEALTHSTATUS = '2'; ARRAYTYPE = '1'; CAPACITYBYTE = '2147483648' }
                    )
                    break
                }
                'REPLICATIONPAIR/*' {
                    [pscustomobject]@{ ID = 'rp-01'; LOCALRESNAME = 'local-lun'; REMOTERESNAME = 'remote-lun'; REMOTEDEVICENAME = 'remote-a'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '23'; REPLICATIONMODEL = '2'; REPLICATIONPROGRESS = '48' }
                    break
                }
                'REPLICATIONPAIR*' {
                    @([pscustomobject]@{ ID = 'rp-01'; LOCALRESNAME = 'local-lun'; REMOTERESNAME = 'remote-lun'; REMOTEDEVICENAME = 'remote-a'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '23'; REPLICATIONMODEL = '2'; REPLICATIONPROGRESS = '48' })
                    break
                }
                'CONSISTENTGROUP/*' {
                    [pscustomobject]@{ ID = 'rcg-01'; NAME = 'rep-group'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '26'; REPLICATIONMODEL = '2'; SPEED = '3'; RECOVERYPOLICY = '1' }
                    break
                }
                'CONSISTENTGROUP*' {
                    @([pscustomobject]@{ ID = 'rcg-01'; NAME = 'rep-group'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '26'; REPLICATIONMODEL = '2'; SPEED = '3'; RECOVERYPOLICY = '1' })
                    break
                }
                'HyperMetroDomain/*' {
                    [pscustomobject]@{ ID = 'domain-01'; NAME = 'metro-domain'; DOMAINTYPE = '0'; RUNNINGSTATUS = '1'; CPTYPE = '2'; CPSNAME = 'quorum-a' }
                    break
                }
                'HyperMetroDomain*' {
                    @([pscustomobject]@{ ID = 'domain-01'; NAME = 'metro-domain'; DOMAINTYPE = '0'; RUNNINGSTATUS = '1'; CPTYPE = '2'; CPSNAME = 'quorum-a' })
                    break
                }
                'HyperMetroPair/*' {
                    [pscustomobject]@{ ID = 'hmp-01'; LOCALOBJNAME = 'local-lun'; REMOTEOBJNAME = 'remote-lun'; DOMAINNAME = 'metro-domain'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '23'; LINKSTATUS = '10'; ISPRIMARY = 'true' }
                    break
                }
                'HyperMetroPair*' {
                    @([pscustomobject]@{ ID = 'hmp-01'; LOCALOBJNAME = 'local-lun'; REMOTEOBJNAME = 'remote-lun'; DOMAINNAME = 'metro-domain'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '23'; LINKSTATUS = '10'; ISPRIMARY = 'true' })
                    break
                }
                'HyperMetro_ConsistentGroup/*' {
                    [pscustomobject]@{ ID = 'hmcg-01'; NAME = 'metro-group'; DOMAINNAME = 'metro-domain'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '41'; PRIORITYSTATION = '0'; RECOVERYPOLICY = '1' }
                    break
                }
                'HyperMetro_ConsistentGroup*' {
                    @([pscustomobject]@{ ID = 'hmcg-01'; NAME = 'metro-group'; DOMAINNAME = 'metro-domain'; HEALTHSTATUS = '1'; RUNNINGSTATUS = '41'; PRIORITYSTATION = '0'; RECOVERYPOLICY = '1' })
                    break
                }
            }
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $data }
        }
    }

    It 'gets remote devices from the documented collection resource' {
        $result = @(Get-DMRemoteDevice -WebSession $script:session)

        $result[0].GetType().Name | Should -Be 'OceanstorRemoteDevice'
        $result[0].'Running Status' | Should -Be 'Link Up'
        $script:resource | Should -BeLike 'remote_device?range=*'
    }

    It 'gets one remote device by exact id' {
        $result = Get-DMRemoteDevice -WebSession $script:session -Id '0'

        $result.Name | Should -Be 'remote-a'
        $script:resource | Should -Be 'remote_device/0'
    }

    It 'gets remote LUNs for a replication remote device' {
        $result = @(Get-DMRemoteLun -WebSession $script:session -RemoteDeviceId '0' -Name 'remote-lun-a')

        $result.Count | Should -Be 1
        $result[0].GetType().Name | Should -Be 'OceanstorRemoteLun'
        $result[0].'Capacity Bytes' | Should -Be '1073741824'
        $script:resource | Should -BeLike 'remote_lun?RSSTYPE=13&DEVICEID=0&ARRAYTYPE=1&range=*'
    }

    It 'gets remote replication pairs from REPLICATIONPAIR' {
        $result = @(Get-DMReplicationPair -WebSession $script:session)

        $result[0].GetType().Name | Should -Be 'OceanstorReplicationPair'
        $result[0].'Running Status' | Should -Be 'Synchronizing'
        $script:resource | Should -BeLike 'REPLICATIONPAIR?range=*'
    }

    It 'gets a remote replication pair by exact id' {
        $result = Get-DMReplicationPair -WebSession $script:session -Id 'rp-01'

        $result.Id | Should -Be 'rp-01'
        $script:resource | Should -Be 'REPLICATIONPAIR/rp-01'
    }

    It 'gets remote replication consistency groups from CONSISTENTGROUP' {
        $result = @(Get-DMReplicationConsistencyGroup -WebSession $script:session)

        $result[0].GetType().Name | Should -Be 'OceanstorReplicationConsistencyGroup'
        $result[0].Name | Should -Be 'rep-group'
        $script:resource | Should -BeLike 'CONSISTENTGROUP?range=*'
    }

    It 'gets HyperMetro domains from HyperMetroDomain' {
        $result = @(Get-DMHyperMetroDomain -WebSession $script:session)

        $result[0].GetType().Name | Should -Be 'OceanstorHyperMetroDomain'
        $result[0].'Domain Type' | Should -Be 'SAN'
        $script:resource | Should -BeLike 'HyperMetroDomain?range=*'
    }

    It 'gets HyperMetro pairs from HyperMetroPair' {
        $result = @(Get-DMHyperMetroPair -WebSession $script:session)

        $result[0].GetType().Name | Should -Be 'OceanstorHyperMetroPair'
        $result[0].'Link Status' | Should -Be 'Link Up'
        $script:resource | Should -BeLike 'HyperMetroPair?range=*'
    }

    It 'gets HyperMetro consistency groups from HyperMetro_ConsistentGroup' {
        $result = @(Get-DMHyperMetroConsistencyGroup -WebSession $script:session)

        $result[0].GetType().Name | Should -Be 'OceanstorHyperMetroConsistencyGroup'
        $result[0].'Running Status' | Should -Be 'Suspended'
        $script:resource | Should -BeLike 'HyperMetro_ConsistentGroup?range=*'
    }

    It 'gets a HyperMetro consistency group by exact id' {
        $result = Get-DMHyperMetroConsistencyGroup -WebSession $script:session -Id 'hmcg-01'

        $result.Name | Should -Be 'metro-group'
        $script:resource | Should -Be 'HyperMetro_ConsistentGroup/hmcg-01'
    }
}
}
