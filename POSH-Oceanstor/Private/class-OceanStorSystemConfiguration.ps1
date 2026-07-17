class OceanStorSystemConfigObject {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    OceanStorSystemConfigObject([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
    }

    static [object] GetValue([object]$Source, [string[]]$Names) {
        if ($null -eq $Source) { return $null }
        foreach ($name in $Names) {
            $property = $Source.PSObject.Properties[$name]
            if ($null -ne $property) { return $property.Value }
        }
        return $null
    }

    static [string] GetString([object]$Source, [string[]]$Names) {
        $value = [OceanStorSystemConfigObject]::GetValue($Source, $Names)
        if ($null -eq $value) { return $null }
        return [string]$value
    }
}

class OceanStorNtpConfig : OceanStorSystemConfigObject {
    [string[]]${Server Addresses}
    [bool]$Enabled
    [string]${Sync Period}
    [bool]${Authentication Enabled}

    OceanStorNtpConfig([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $addresses = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_SYS_NTP_CLNT_CONF_SERVER_IP'))
        $this.{Server Addresses} = @($addresses -split ',' | Where-Object { $_ })
        $this.Enabled = ([OceanStorSystemConfigObject]::GetString($Source, @('CMO_SYS_NTP_CLNT_CONF_SWITCH')) -eq '1')
        $this.{Sync Period} = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_SYS_NTP_SYNC_PERIOD'))
        $this.{Authentication Enabled} = ([OceanStorSystemConfigObject]::GetString($Source, @('CMO_SYS_NTP_CLNT_CONF_AUTH_SWITCH')) -eq '1')
    }
}

class OceanStorNtpStatus : OceanStorSystemConfigObject {
    [string[]]${Configured Servers}
    [string]${Connected Server}
    [string]$Status

    OceanStorNtpStatus([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $addresses = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_SYS_NTP_CLNT_CONF_SERVER_IP'))
        $this.{Configured Servers} = @($addresses -split ',' | Where-Object { $_ })
        $this.{Connected Server} = [OceanStorSystemConfigObject]::GetString($Source, @('currentConnectedNTPServer'))
        $this.Status = [OceanStorSystemConfigObject]::GetString($Source, @('status'))
    }
}

class OceanStorSnmpTrapServer : OceanStorSystemConfigObject {
    [string]$Id
    [string]$Address
    [string]$Port
    [string]$User
    [string]$Type
    [string]$Version

    OceanStorSnmpTrapServer([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $this.Id = [OceanStorSystemConfigObject]::GetString($Source, @('ID', 'id'))
        $this.Address = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_TRAP_SERVER_IP'))
        $this.Port = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_TRAP_SERVER_PORT'))
        $this.User = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_TRAP_SERVER_USER'))
        $this.Type = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_TRAP_SERVER_TYPE'))
        $this.Version = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_TRAP_VERSION'))
    }
}

class OceanStorSnmpConfig : OceanStorSystemConfigObject {
    [string]${IPv4 Address}
    [string]${IPv6 Address}
    [string]${Unique Engine Id}

    OceanStorSnmpConfig([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $this.{IPv4 Address} = [OceanStorSystemConfigObject]::GetString($Source, @('SNMP_ADDRESS_IPV4'))
        $this.{IPv6 Address} = [OceanStorSystemConfigObject]::GetString($Source, @('SNMP_ADDRESS_IPV6'))
        $this.{Unique Engine Id} = [OceanStorSystemConfigObject]::GetString($Source, @('SNMP_UNIQUE_ENGINEID'))
    }
}

class OceanStorSnmpSecurityPolicy : OceanStorSystemConfigObject {
    [string]${Minimum Security}
    [string]${Safe Strategy}

    OceanStorSnmpSecurityPolicy([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $this.{Minimum Security} = [OceanStorSystemConfigObject]::GetString($Source, @('MIN_SECURITY_LEVEL', 'SAFE_STRATEGY_MIN_SECURITY_LEVEL'))
        $this.{Safe Strategy} = [OceanStorSystemConfigObject]::GetString($Source, @('SAFE_STRATEGY', 'SAFE_STRATEGY_PWD_COMPLEXITY'))
    }
}

class OceanStorSnmpUsmUser : OceanStorSystemConfigObject {
    [string]$Name
    [string]${Authentication Protocol}
    [string]${Privacy Protocol}
    [string]${User Level}
    [bool]${Is Default}

    OceanStorSnmpUsmUser([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $this.Name = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_USM_USER'))
        $this.{Authentication Protocol} = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_USM_AUTH_PROT'))
        $this.{Privacy Protocol} = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_USM_PRIV_PROT'))
        $this.{User Level} = [OceanStorSystemConfigObject]::GetString($Source, @('CMO_USM_USER_LEVEL'))
        $this.{Is Default} = ([OceanStorSystemConfigObject]::GetString($Source, @('CMO_USM_ISDEFAULT')) -eq 'true')
    }
}

class OceanStorSyslogNotification : OceanStorSystemConfigObject {
    [string[]]${Server Addresses}
    [string]$Format
    [string]$Protocol
    [string]$Port

    OceanStorSyslogNotification([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        # The syslog GET interface returns the receiver address under
        # CMO_ALARM_SYSLOG_SERVER_IP (see REST reference 4.2.2); older/other builds
        # may expose CMO_SYSLOG_SERVER_IP(_LIST), so both are accepted here.
        $addresses = [OceanStorSystemConfigObject]::GetValue($Source, @('CMO_SYSLOG_SERVER_IP', 'CMO_SYSLOG_SERVER_IP_LIST', 'CMO_ALARM_SYSLOG_SERVER_IP', 'CMO_ALARM_SYSLOG_SERVER_IP_LIST'))
        $this.{Server Addresses} = @($addresses)
        $this.Format = [OceanStorSystemConfigObject]::GetString($Source, @('syslogFormat'))
        $this.Protocol = [OceanStorSystemConfigObject]::GetString($Source, @('protocol', 'CMO_SYSLOG_PROTOCOL'))
        $this.Port = [OceanStorSystemConfigObject]::GetString($Source, @('port', 'CMO_SYSLOG_SERVER_PORT'))
    }
}

class OceanStorLocalUser : OceanStorSystemConfigObject {
    [string]$Id
    [string]$Name
    [string]$Description
    [string]${Role Id}
    [string]${Role Name}
    [string]${User Type}
    [string]$Status

    OceanStorLocalUser([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $this.Id = [OceanStorSystemConfigObject]::GetString($Source, @('ID', 'id', 'userid'))
        $this.Name = [OceanStorSystemConfigObject]::GetString($Source, @('NAME', 'name', 'USERNAME', 'username'))
        $this.Description = [OceanStorSystemConfigObject]::GetString($Source, @('DESCRIPTION', 'description'))
        $this.{Role Id} = [OceanStorSystemConfigObject]::GetString($Source, @('roleId'))
        $this.{Role Name} = [OceanStorSystemConfigObject]::GetString($Source, @('roleName', 'ROLENAME'))
        $this.{User Type} = [OceanStorSystemConfigObject]::GetString($Source, @('userType', 'USERTYPE'))
        $this.Status = [OceanStorSystemConfigObject]::GetString($Source, @('status', 'STATUS'))
    }
}

class OceanStorRole : OceanStorSystemConfigObject {
    [string]$Id
    [string]$Name
    [string]$Description
    [string]${Owner Group}
    [string]${Role Source}

    OceanStorRole([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $this.Id = [OceanStorSystemConfigObject]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanStorSystemConfigObject]::GetString($Source, @('name', 'NAME'))
        $this.Description = [OceanStorSystemConfigObject]::GetString($Source, @('description', 'DESCRIPTION'))
        $this.{Owner Group} = [OceanStorSystemConfigObject]::GetString($Source, @('roleOwnerGroup'))
        $this.{Role Source} = [OceanStorSystemConfigObject]::GetString($Source, @('roleSource'))
    }
}

class OceanStorRolePermission : OceanStorSystemConfigObject {
    [string]$Id
    [string]$Name
    [string]$Description

    OceanStorRolePermission([object]$Source, [pscustomobject]$WebSession) : base($Source, $WebSession) {
        $this.Id = [OceanStorSystemConfigObject]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanStorSystemConfigObject]::GetString($Source, @('name', 'NAME'))
        $this.Description = [OceanStorSystemConfigObject]::GetString($Source, @('description', 'DESCRIPTION'))
    }
}
