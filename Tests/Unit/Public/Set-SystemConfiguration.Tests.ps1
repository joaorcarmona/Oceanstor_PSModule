BeforeDiscovery {
    $script:systemConfigurationMutationModule = New-Module -Name SystemConfigurationMutationTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [switch]$ApiV2
            )
        }

        # Set-DMSnmpTrapServer performs a read-modify-write via the sibling
        # Get-DMSnmpTrapServer (a Get- verb, so it is not dot-sourced by the mutating
        # loop below). Provide a mockable stub so the modify test stays isolated.
        function Get-DMSnmpTrapServer {
            param(
                [pscustomobject]$WebSession,
                [string]$Id
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Test-DMNetworkAddress.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Test-IPv4Address.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\ConvertFrom-DMSensitiveValue.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\New-DMRequestBody.ps1"

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Public" -Filter '*-DM*.ps1' |
            Where-Object Name -match '^(Add|Disable|Lock|New|Remove|Reset|Set|Test|Unlock)-DM' |
            ForEach-Object { . $_.FullName }

        Export-ModuleMember -Function '*-DM*'
    }

    Import-Module $script:systemConfigurationMutationModule -Force
}

AfterAll {
    Remove-Module -Name SystemConfigurationMutationTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SystemConfigurationMutationTestModule {
Describe 'System configuration mutation functions' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:method = $null
        $script:resource = $null
        $script:body = $null
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:body = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'item-01' } }
        }
        # Read half of Set-DMSnmpTrapServer's read-modify-write; supplied fields in
        # the tests override these, so the modify test's assertions are unaffected.
        Mock Get-DMSnmpTrapServer {
            [pscustomobject]@{
                Id      = $Id
                Address = '10.0.0.9'
                Port    = '162'
                User    = 'existingUser'
                Type    = '3'
                Version = '1'
            }
        }
    }

    It 'sets NTP server configuration' {
        $result = Set-DMNtpServer -WebSession $script:session -Address '10.0.0.1', '10.0.0.2' -SyncPeriod 7200 -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'ntp_client_config'
        $script:body.CMO_SYS_NTP_CLNT_CONF_SERVER_IP | Should -Be '10.0.0.1,10.0.0.2'
        $script:body.CMO_SYS_NTP_CLNT_CONF_SWITCH | Should -Be '1'
        $script:body.CMO_SYS_NTP_SYNC_PERIOD | Should -Be '7200'
    }

    It 'sets LLDP working mode' {
        $result = Set-DMLLDPWorkingMode -WebSession $script:session -WorkingMode Transmit -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'LLDP_WORKING_MODE'
        $script:body.lldpWorkingMode | Should -Be '1'
    }

    It 'tests an NTP server address' {
        $null = Test-DMNtpServer -WebSession $script:session -Address '10.0.0.1'

        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'check_ntp_server_address_connective'
        $script:body.CMO_SYS_NTP_CLNT_CONF_SERVER_IP | Should -Be '10.0.0.1'
    }

    It 'accepts FQDN and IPv6 server addresses and rejects malformed addresses' {
        $null = Set-DMNtpServer -WebSession $script:session -Address 'time.example.com', '2001:db8::1' -Confirm:$false

        $script:body.CMO_SYS_NTP_CLNT_CONF_SERVER_IP | Should -Be 'time.example.com,2001:db8::1'

        { New-DMSnmpTrapServer -WebSession $script:session -Address 'not a host' -Port 162 -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*IPv4 address, IPv6 address, or fully qualified domain name*'

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'creates an SNMP trap server' {
        $null = New-DMSnmpTrapServer -WebSession $script:session -Address '192.0.2.10' -Port 162 -User 'usm01' -Type '3' -Version '3' -Confirm:$false

        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'snmp_trap_addr'
        $script:body.CMO_TRAP_SERVER_IP | Should -Be '192.0.2.10'
        $script:body.CMO_TRAP_SERVER_PORT | Should -Be '162'
        $script:body.CMO_TRAP_SERVER_USER | Should -Be 'usm01'
    }

    It 'modifies an SNMP trap server with an encoded id' {
        $null = Set-DMSnmpTrapServer -WebSession $script:session -Id 'trap/01' -Address '192.0.2.11' -Port 1162 -Confirm:$false

        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'snmp_trap_addr/trap%2F01'
        $script:body.CMO_TRAP_SERVER_PORT | Should -Be '1162'
    }

    It 'removes an SNMP trap server with an encoded id' {
        $null = Remove-DMSnmpTrapServer -WebSession $script:session -Id 'trap/01' -Confirm:$false

        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'snmp_trap_addr/trap%2F01'
    }

    It 'tests an SNMP trap server' {
        $null = Test-DMSnmpTrapServer -WebSession $script:session -Address '192.0.2.10' -Port 162 -Version '3'

        $script:resource | Should -Be 'snmp_trap_addr/send_test_trapmsg'
        $script:body.CMO_TRAP_VERSION | Should -Be '3'
    }

    It 'sets SNMP protocol, security, and community resources' {
        $null = Set-DMSnmpConfig -WebSession $script:session -Property @{ SNMP_VERSION = '3' } -Confirm:$false
        $script:resource | Should -Be 'common/snmp_protocol'
        $script:body.SNMP_VERSION | Should -Be '3'

        $null = Set-DMSnmpSecurityPolicy -WebSession $script:session -Property @{ SAFE_STRATEGY = '1' } -Confirm:$false
        $script:resource | Should -Be 'common/snmp_security_policies'

        $null = Set-DMSnmpCommunity -WebSession $script:session -Property @{ SNMP_COMMUNITY = 'public' } -Confirm:$false
        $script:resource | Should -Be 'SNMP_COMMUNITY'
    }

    It 'accepts SecureString values for SNMP community and USM passwords' {
        $community = ConvertTo-SecureString 'private-community' -AsPlainText -Force
        $authPassword = ConvertTo-SecureString 'auth-secret' -AsPlainText -Force

        $null = Set-DMSnmpCommunity -WebSession $script:session -Community $community -Confirm:$false
        $script:body.SNMP_COMMUNITY | Should -Be 'private-community'

        $null = New-DMSnmpUsmUser -WebSession $script:session -Name 'usm-secure' -AuthPassword $authPassword -Confirm:$false
        $script:body.CMO_USM_PASSWD | Should -Be 'auth-secret'
    }

    It 'creates, modifies, and removes SNMP USM users' {
        $null = New-DMSnmpUsmUser -WebSession $script:session -Name 'usm01' -AuthProtocol '3' -AuthPassword 'secret' -UserLevel 0 -Confirm:$false
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'snmp_usm'
        $script:body.CMO_USM_USER | Should -Be 'usm01'

        $null = Set-DMSnmpUsmUser -WebSession $script:session -Name 'usm01' -PrivacyProtocol '4' -Confirm:$false
        $script:method | Should -Be 'PUT'
        $script:body.CMO_USM_PRIV_PROT | Should -Be '4'

        $null = Remove-DMSnmpUsmUser -WebSession $script:session -Id 'usm/01' -Confirm:$false
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'snmp_usm/usm%2F01'
    }

    It 'sets syslog notification and manages syslog servers' {
        $null = Set-DMSyslogNotification -WebSession $script:session -Property @{ syslogFormat = '1' } -Confirm:$false
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'syslog'

        $null = Add-DMSyslogServer -WebSession $script:session -Address '192.0.2.20' -Confirm:$false
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'syslog_addip'
        # syslog_addip's mandatory field is CMO_ALARM_SYSLOG_SERVER_IP (REST reference
        # 4.2.2.1.1); the field-name fix landed 2026-07-17 (see docs/system-management/TODO.md).
        $script:body.CMO_ALARM_SYSLOG_SERVER_IP | Should -Be '192.0.2.20'

        $null = Remove-DMSyslogServer -WebSession $script:session -Address '192.0.2.20' -Confirm:$false
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'syslog_removeip'
    }

    It 'sets syslog severity, port, and protocol using named parameters' {
        $null = Set-DMSyslogNotification -WebSession $script:session -Severity 5 -Port 514 -Protocol 'TCP' -Confirm:$false

        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'syslog'
        $script:body.CMO_ALARM_SYSLOG_SEVERITY | Should -Be 5
        $script:body.SYSLOG_SERVER_PORT | Should -Be 514
        $script:body.SYSLOG_SERVER_CHANNEL_PROTOCOL | Should -Be 2
    }

    It 'only includes explicitly bound syslog named parameters in the request body' {
        $null = Set-DMSyslogNotification -WebSession $script:session -Port 514 -Confirm:$false

        $script:body.Keys | Should -Not -Contain 'CMO_ALARM_SYSLOG_SEVERITY'
        $script:body.Keys | Should -Not -Contain 'SYSLOG_SERVER_CHANNEL_PROTOCOL'
        $script:body.SYSLOG_SERVER_PORT | Should -Be 514
    }

    It 'merges named syslog parameters over -Property values' {
        $null = Set-DMSyslogNotification -WebSession $script:session -Property @{ syslogFormat = '1' } -Severity 2 -Confirm:$false

        $script:body.syslogFormat | Should -Be '1'
        $script:body.CMO_ALARM_SYSLOG_SEVERITY | Should -Be 2
    }

    It 'rejects an out-of-range syslog severity value' {
        { Set-DMSyslogNotification -WebSession $script:session -Severity 4 -Confirm:$false } | Should -Throw
    }

    It 'rejects an out-of-range syslog port value' {
        { Set-DMSyslogNotification -WebSession $script:session -Port 70000 -Confirm:$false } | Should -Throw
    }

    It 'rejects an unsupported syslog protocol value' {
        { Set-DMSyslogNotification -WebSession $script:session -Protocol 'SSL' -Confirm:$false } | Should -Throw
    }

    It 'does not call the syslog API when WhatIf is used' {
        $null = Set-DMSyslogNotification -WebSession $script:session -Severity 5 -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'sets equipment time zone' {
        $result = Set-DMTimeZone -WebSession $script:session -TimeZoneName 'Asia/Beijing' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'system_timezone'
        $script:body.CMO_SYS_TIME_ZONE_NAME | Should -Be 'Asia/Beijing'
    }

    It 'sets equipment UTC time' {
        $result = Set-DMutcTime -WebSession $script:session -UtcTime 1478179247 -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'system_utc_time'
        $script:body.CMO_SYS_UTC_TIME | Should -Be 1478179247
    }

    It 'creates, modifies, and removes local users' {
        $null = New-DMLocalUser -WebSession $script:session -Name 'audit' -Password 'secret' -RoleId '1' -Confirm:$false
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'user'
        $script:body.NAME | Should -Be 'audit'
        $script:body.roleId | Should -Be '1'

        $null = Set-DMLocalUser -WebSession $script:session -Id 'audit/user' -Description 'updated' -Confirm:$false
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'user/audit%2Fuser'
        $script:body.DESCRIPTION | Should -Be 'updated'

        $null = Remove-DMLocalUser -WebSession $script:session -Id 'audit/user' -Confirm:$false
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'user/audit%2Fuser'
    }

    It 'accepts SecureString values for local user passwords' {
        $password = ConvertTo-SecureString 'user-secret' -AsPlainText -Force
        $oldPassword = ConvertTo-SecureString 'old-secret' -AsPlainText -Force

        $null = New-DMLocalUser -WebSession $script:session -Name 'secure-user' -Password $password -Confirm:$false
        $script:body.PASSWORD | Should -Be 'user-secret'

        $null = Set-DMLocalUser -WebSession $script:session -Id 'secure-user' -Password $password -OldPassword $oldPassword -Confirm:$false
        $script:body.PASSWORD | Should -Be 'user-secret'
        $script:body.OLDPASSWORD | Should -Be 'old-secret'

        $null = Reset-DMLocalUserPassword -WebSession $script:session -Id 'secure-user' -Password $password -Confirm:$false
        $script:body.PASSWORD | Should -Be 'user-secret'
    }

    It 'runs local user action commands' {
        $null = Lock-DMLocalUser -WebSession $script:session -Id 'audit/user' -Confirm:$false
        $script:resource | Should -Be 'lockuser/audit%2Fuser'

        $null = Unlock-DMLocalUser -WebSession $script:session -Id 'audit/user' -Confirm:$false
        $script:resource | Should -Be 'unlockuser/audit%2Fuser'

        $null = Disable-DMLocalUserSession -WebSession $script:session -Id 'audit/user' -Confirm:$false
        $script:resource | Should -Be 'offline_user/audit%2Fuser'

        $null = Reset-DMLocalUserPassword -WebSession $script:session -Id 'audit/user' -Password 'newSecret' -Confirm:$false
        $script:resource | Should -Be 'initialize_user_pwd/audit%2Fuser'
        $script:body.PASSWORD | Should -Be 'newSecret'
    }

    It 'creates, modifies, and removes roles' {
        $null = New-DMRole -WebSession $script:session -Name 'Auditor' -RoleOwnerGroup '1' -RoleSource '1' -Confirm:$false
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'role'
        $script:body.name | Should -Be 'Auditor'

        $null = Set-DMRole -WebSession $script:session -Id 'role/01' -Description 'updated' -Confirm:$false
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'role/role%2F01'
        $script:body.description | Should -Be 'updated'
        # Regression guard for OceanStor API error 50331651: the modify interface (REST
        # reference 4.3.6.3.1) marks id (lowercase) as a Mandatory body field; sending
        # description alone (id only in the URL path) is rejected by the array.
        $script:body.id | Should -Be 'role/01'

        $null = Remove-DMRole -WebSession $script:session -Id 'role/01' -Confirm:$false
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'role'
        $script:body.ID | Should -Be 'role/01'
    }

    It 'sets DNS servers' {
        $result = Set-DMdnsServer -WebSession $script:session -DNSserver '8.8.8.8', '1.1.1.1' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'dns_server'
        $script:body.ADDRESS | Should -Be @('8.8.8.8', '1.1.1.1')
    }

    It 'rejects DNS server addresses that are not valid IPv4 addresses' {
        { Set-DMdnsServer -WebSession $script:session -DNSserver '8.8.8.8', 'not-an-ip' -Confirm:$false } |
            Should -Throw "*'not-an-ip' is not a valid IPv4 address*"

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'does not call the DNS API when WhatIf is used' {
        $null = Set-DMdnsServer -WebSession $script:session -DNSserver '8.8.8.8' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'does not call mutating APIs when WhatIf is used' {
        $null = Set-DMNtpServer -WebSession $script:session -Address '10.0.0.1' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'does not call the SNMP trap server APIs when WhatIf is used' {
        $null = New-DMSnmpTrapServer -WebSession $script:session -Address '192.0.2.10' -Port 162 -WhatIf
        $null = Set-DMSnmpTrapServer -WebSession $script:session -Id 'trap/01' -Port 1162 -WhatIf
        $null = Remove-DMSnmpTrapServer -WebSession $script:session -Id 'trap/01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        $script:body | Should -BeNullOrEmpty
    }

    It 'does not call the SNMP USM user APIs when WhatIf is used' {
        $null = New-DMSnmpUsmUser -WebSession $script:session -Name 'usm01' -AuthProtocol '3' -AuthPassword 'secret' -UserLevel 0 -WhatIf
        $null = Set-DMSnmpUsmUser -WebSession $script:session -Name 'usm01' -UserLevel 1 -WhatIf
        $null = Remove-DMSnmpUsmUser -WebSession $script:session -Id 'usm01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        $script:body | Should -BeNullOrEmpty
    }

    It 'does not call the syslog server APIs when WhatIf is used' {
        $null = Add-DMSyslogServer -WebSession $script:session -Address '192.0.2.20' -WhatIf
        $null = Remove-DMSyslogServer -WebSession $script:session -Address '192.0.2.20' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        $script:body | Should -BeNullOrEmpty
    }

    It 'does not call the local user APIs when WhatIf is used' {
        $null = New-DMLocalUser -WebSession $script:session -Name 'poshtest-user' -Password 'secret' -RoleId '1' -WhatIf
        $null = Set-DMLocalUser -WebSession $script:session -Id 'poshtest-user' -Description 'updated' -WhatIf
        $null = Remove-DMLocalUser -WebSession $script:session -Id 'poshtest-user' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        $script:body | Should -BeNullOrEmpty
    }

    It 'does not call the role APIs when WhatIf is used' {
        $null = New-DMRole -WebSession $script:session -Name 'poshtest-role' -RoleOwnerGroup '1' -RoleSource '1' -WhatIf
        $null = Set-DMRole -WebSession $script:session -Id 'role/01' -Description 'updated' -WhatIf
        $null = Remove-DMRole -WebSession $script:session -Id 'role/01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        $script:body | Should -BeNullOrEmpty
    }
}
}
