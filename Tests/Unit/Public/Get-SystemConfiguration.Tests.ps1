BeforeDiscovery {
    $script:systemConfigurationModule = New-Module -Name SystemConfigurationGetterTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
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
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorSystemConfiguration.ps1"

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMNtpServer.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMNtpStatus.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMSnmpTrapServer.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMSnmpConfig.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMSnmpSecurityPolicy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMSnmpUsmUser.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMSyslogNotification.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMLocalUser.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMRole.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMRolePermission.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMEquipmentStatus.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMTimeZone.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMutcTime.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMdnsServer.ps1"

        Export-ModuleMember -Function 'Get-DMNtpServer', 'Get-DMNtpStatus', 'Get-DMSnmpTrapServer',
            'Get-DMSnmpConfig', 'Get-DMSnmpSecurityPolicy', 'Get-DMSnmpUsmUser',
            'Get-DMSyslogNotification', 'Get-DMLocalUser', 'Get-DMRole', 'Get-DMRolePermission',
            'Get-DMEquipmentStatus', 'Get-DMTimeZone', 'Get-DMutcTime', 'Get-DMdnsServer'
    }

    Import-Module $script:systemConfigurationModule -Force
}

AfterAll {
    Remove-Module -Name SystemConfigurationGetterTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SystemConfigurationGetterTestModule {
Describe 'System configuration getter functions' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:resource = $null
        $script:method = $null
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'item-01'; NAME = 'item' } }
        }
    }

    It 'gets NTP server configuration' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{
                    CMO_SYS_NTP_CLNT_CONF_SERVER_IP = '10.0.0.1,10.0.0.2'
                    CMO_SYS_NTP_CLNT_CONF_SWITCH = '1'
                    CMO_SYS_NTP_SYNC_PERIOD = '7200'
                }
            }
        }

        $result = Get-DMNtpServer -WebSession $script:session

        $result.GetType().Name | Should -Be 'OceanStorNtpConfig'
        $result.'Server Addresses' | Should -Be @('10.0.0.1', '10.0.0.2')
        $result.Enabled | Should -BeTrue
        $result.'Sync Period' | Should -Be '7200'
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'ntp_client_config'
    }

    It 'gets NTP status' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{
                    CMO_SYS_NTP_CLNT_CONF_SERVER_IP = '10.0.0.1'
                    currentConnectedNTPServer = '10.0.0.1'
                    status = '1'
                }
            }
        }

        $result = Get-DMNtpStatus -WebSession $script:session

        $result.GetType().Name | Should -Be 'OceanStorNtpStatus'
        $result.'Connected Server' | Should -Be '10.0.0.1'
        $script:resource | Should -Be 'ntp_client_config/get_ntp_status'
    }

    It 'gets SNMP configuration' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{ SNMP_ADDRESS_IPV4 = '192.0.2.1'; SNMP_UNIQUE_ENGINEID = 'engine-01' }
            }
        }

        $result = Get-DMSnmpConfig -WebSession $script:session

        $result.GetType().Name | Should -Be 'OceanStorSnmpConfig'
        $result.'IPv4 Address' | Should -Be '192.0.2.1'
        $script:resource | Should -Be 'common/snmp_protocol'
    }

    It 'gets SNMP security policy' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ SAFE_STRATEGY = '1' } }
        }

        $result = Get-DMSnmpSecurityPolicy -WebSession $script:session

        $result.GetType().Name | Should -Be 'OceanStorSnmpSecurityPolicy'
        $result.'Safe Strategy' | Should -Be '1'
        $script:resource | Should -Be 'common/snmp_security_policies'
    }

    It 'gets syslog notification settings' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ CMO_SYSLOG_SERVER_IP = @('192.0.2.20'); syslogFormat = '1' } }
        }

        $result = Get-DMSyslogNotification -WebSession $script:session

        $result.GetType().Name | Should -Be 'OceanStorSyslogNotification'
        $result.'Server Addresses' | Should -Be '192.0.2.20'
        $script:resource | Should -Be 'syslog'
    }

    It 'uses a bounded timeout for syslog notification settings' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            $script:timeout = $TimeoutSec
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ CMO_SYSLOG_SERVER_IP = @('192.0.2.20') } }
        }

        $null = Get-DMSyslogNotification -WebSession $script:session

        $script:resource | Should -Be 'syslog'
        $script:timeout | Should -Be 30
    }

    It 'gets a single SNMP trap server by encoded id' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'trap-01'; CMO_TRAP_SERVER_IP = '192.0.2.10' } }
        }

        $result = Get-DMSnmpTrapServer -WebSession $script:session -Id 'trap/01'

        $result.GetType().Name | Should -Be 'OceanStorSnmpTrapServer'
        $result.Address | Should -Be '192.0.2.10'
        $script:resource | Should -Be 'snmp_trap_addr/trap%2F01'
    }

    It 'gets a single SNMP USM user by encoded id' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ CMO_USM_USER = 'usm01'; CMO_USM_AUTH_PROT = '3' } }
        }

        $result = Get-DMSnmpUsmUser -WebSession $script:session -Id 'user/01'

        $result.GetType().Name | Should -Be 'OceanStorSnmpUsmUser'
        $result.Name | Should -Be 'usm01'
        $script:resource | Should -Be 'snmp_usm/user%2F01'
    }

    It 'gets a single local user by encoded id' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ userid = 'admin'; NAME = 'admin'; roleId = '1' } }
        }

        $result = Get-DMLocalUser -WebSession $script:session -Id 'admin/test'

        $result.GetType().Name | Should -Be 'OceanStorLocalUser'
        $result.'Role Id' | Should -Be '1'
        $script:resource | Should -Be 'user/admin%2Ftest'
    }

    It 'gets a single role by encoded id' {
        Mock Invoke-DeviceManager {
            $script:timeout = $TimeoutSec
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'role-01'; name = 'Auditor'; roleOwnerGroup = '1' } }
        }

        $result = Get-DMRole -WebSession $script:session -Id 'role/01'

        $result.GetType().Name | Should -Be 'OceanStorRole'
        $result.Name | Should -Be 'Auditor'
        $script:resource | Should -Be 'role/role%2F01'
        $script:timeout | Should -Be 30
    }

    It 'gets role permissions for the requested owner group' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            $script:timeout = $TimeoutSec
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = 'perm-01'; name = 'Read' }) }
        }

        $result = @(Get-DMRolePermission -WebSession $script:session -RoleOwnerGroup '1 2')

        $result[0].GetType().Name | Should -Be 'OceanStorRolePermission'
        $result[0].Name | Should -Be 'Read'
        $script:resource | Should -Be 'querying_permissions_available?roleOwnerGroup=1%202'
        $script:timeout | Should -Be 30
    }

    It 'gets equipment status' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{ status = '4'; description = 'Security mode is enabled' }
            }
        }

        $result = Get-DMEquipmentStatus -WebSession $script:session

        $result.Status | Should -Be 4
        $result.StatusName | Should -Be 'SecurityMode'
        $result.Description | Should -Be 'Security mode is enabled'
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'server/status'
    }

    It 'gets equipment time zone' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{
                    CMO_SYS_TIME_ZONE = '8'
                    CMO_SYS_TIME_ZONE_NAME = 'Asia/Beijing'
                    CMO_SYS_TIME_ZONE_NAME_STYLE = '0'
                    CMO_SYS_TIME_ZONE_USE_DST = '1'
                }
            }
        }

        $result = Get-DMTimeZone -WebSession $script:session

        $result.TimeZone | Should -Be '8'
        $result.TimeZoneName | Should -Be 'Asia/Beijing'
        $result.NameStyle | Should -Be '0'
        $result.UsesDaylightTime | Should -BeTrue
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'system_timezone'
    }

    It 'gets equipment UTC time' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{ CMO_SYS_UTC_TIME = '1478179247' }
            }
        }

        $result = Get-DMutcTime -WebSession $script:session

        $result.UtcTime | Should -Be 1478179247
        $result.DateTimeUtc | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1478179247).UtcDateTime)
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'system_utc_time'
    }

    It 'gets DNS servers as a position-keyed hashtable from a JSON-encoded address string' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{ ADDRESS = '["10.0.0.1","10.0.0.2"]' }
            }
        }

        $result = Get-DMdnsServer -WebSession $script:session

        $result | Should -BeOfType [hashtable]
        $result.Count | Should -Be 2
        $result['DNS Server 1'] | Should -Be '10.0.0.1'
        $result['DNS Server 2'] | Should -Be '10.0.0.2'
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'dns_server'
    }

    It 'gets DNS servers when the address payload is already an array and skips empty entries' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{ ADDRESS = @('10.0.0.1', '', '10.0.0.3') }
            }
        }

        $result = Get-DMdnsServer -WebSession $script:session

        $result.Count | Should -Be 2
        $result['DNS Server 1'] | Should -Be '10.0.0.1'
        $result['DNS Server 2'] | Should -Be '10.0.0.3'
        $script:resource | Should -Be 'dns_server'
    }

    It 'gets paged SNMP trap server collections' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = 'trap-01' }) }
        }

        $result = @(Get-DMSnmpTrapServer -WebSession $script:session)

        $result[0].GetType().Name | Should -Be 'OceanStorSnmpTrapServer'
        $result[0].Id | Should -Be 'trap-01'
        $script:resource | Should -BeLike 'snmp_trap_addr?range=*'
    }

    It 'gets paged SNMP USM user collections' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
        }

        $null = Get-DMSnmpUsmUser -WebSession $script:session

        $script:resource | Should -BeLike 'snmp_usm?range=*'
    }

    It 'gets paged local user collections' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
        }

        $null = Get-DMLocalUser -WebSession $script:session

        $script:resource | Should -BeLike 'user?range=*'
    }

    It 'gets role collections with a single unpaged request' {
        # The live 'role' endpoint pads range-paged responses with copies of the
        # first role, so list mode must query the resource unpaged (bug B-1).
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:timeout = $TimeoutSec
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = @(
                    [pscustomobject]@{ ID = '1'; name = 'Super administrator'; roleOwnerGroup = '1' },
                    [pscustomobject]@{ ID = '2'; name = 'Administrator'; roleOwnerGroup = '1' }
                )
            }
        }

        $result = @(Get-DMRole -WebSession $script:session)

        $result.Count | Should -Be 2
        $result[0].GetType().Name | Should -Be 'OceanStorRole'
        $result.Id | Should -Be @('1', '2')
        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'role'
        $script:timeout | Should -Be 30
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'does not page role collections through Invoke-DMPagedRequest' {
        Mock Invoke-DMPagedRequest { @() }
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
        }

        $result = @(Get-DMRole -WebSession $script:session)

        Should -Invoke Invoke-DMPagedRequest -Times 0 -Exactly
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'terminates against an endpoint that pads range-paged responses' {
        # Simulates the live array behavior that caused the hang: any range
        # request returns a full page of duplicates and never a short page,
        # while the unpaged resource returns the true collection.
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            if ($Resource -match 'range=') {
                $paddedPage = @(1..100 | ForEach-Object { [pscustomobject]@{ ID = '1'; name = 'Super administrator' } })
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $paddedPage }
            }
            else {
                $roles = @(1..15 | ForEach-Object { [pscustomobject]@{ ID = "$_"; name = "role$_" } })
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $roles }
            }
        }

        $result = @(Get-DMRole -WebSession $script:session)

        $result.Count | Should -Be 15
        @($result.Id | Sort-Object -Unique).Count | Should -Be 15
        $script:resource | Should -Be 'role'
    }
}
}
