BeforeDiscovery {
    $script:exportFunctionsModule = New-Module -Name ExportFunctionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        class OceanstorViewStorage {
            [string]$Hostname

            OceanstorViewStorage([string]$Hostname) {
                $this.Hostname = $Hostname
            }
        }

        function Export-Excel {
            param(
                [Parameter(Position = 0)]
                [string]$ReportFile,

                [switch]$AutoSize,

                [string]$TableName,

                [object]$InputObject,

                [string]$WorksheetName
            )
        }

        function New-DMObjectReport {
            param(
                [object]$Object,
                [string]$ReportType
            )
        }

        function Get-DMSystemPerformance {
            param([pscustomobject]$WebSession)
        }

        function Get-DMControllerPerformance {
            param([pscustomobject]$WebSession, [object[]]$InputObject)
        }

        function Get-DMStoragePoolPerformance {
            param([pscustomobject]$WebSession, [object[]]$InputObject)
        }

        function Get-DMDiskPerformance {
            param([pscustomobject]$WebSession, [object[]]$InputObject)
        }

        function Get-DMHostPerformance {
            param([pscustomobject]$WebSession, [object[]]$InputObject)
        }

        function Get-DMLunPerformance {
            param([pscustomobject]$WebSession, [object[]]$InputObject)
        }

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Public" -Filter 'Export-*.ps1' |
            ForEach-Object { . $_.FullName }

        Export-ModuleMember -Function 'Export-*'
    }

    Import-Module $script:exportFunctionsModule -Force
}

AfterAll {
    Remove-Module -Name ExportFunctionsTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope ExportFunctionsTestModule {
Describe 'Public export functions' {
    BeforeEach {
        Mock Export-Excel {}
        Mock New-DMObjectReport {
            [pscustomobject]@{ Source = $Object; ReportType = $ReportType }
        }
        Mock Get-DMSystemPerformance {}
        Mock Get-DMControllerPerformance {}
        Mock Get-DMStoragePoolPerformance {}
        Mock Get-DMDiskPerformance {}
        Mock Get-DMHostPerformance {}
        Mock Get-DMLunPerformance {}
    }

    It 'creates a storage export for the requested hostname' {
        $result = Export-DeviceManager -Hostname 'oceanstor.test'

        $result.GetType().Name | Should -Be 'OceanstorViewStorage'
        $result.Hostname | Should -Be 'oceanstor.test'
    }

    It 'exports inventory rows from a supplied storage object' {
        $storage = [pscustomobject]@{
            Hostname         = 'oceanstor.test'
            Enclosures       = @([pscustomobject]@{ Id = 'enc-01'; Name = 'enc'; 'Part Number' = 'part-enc'; 'Serial Number' = 'sn-enc'; Description = 'enclosure' })
            Controllers      = @([pscustomobject]@{ Id = 'ctrl-01'; Name = 'ctrl'; 'Part Number' = 'part-ctrl'; 'Serial Number' = 'sn-ctrl'; Description = 'controller' })
            disks            = @([pscustomobject]@{ Id = 'disk-01'; Name = 'disk'; 'Part Number' = 'part-disk'; 'Serial Number' = 'sn-disk'; Description = 'disk' })
            InterfaceModules = @([pscustomobject]@{ Id = 'module-01'; Name = 'module'; 'Part Number' = 'part-module'; 'Serial Number' = 'sn-module'; Description = 'module' })
        }

        Export-DMInventory -OceanStor $storage -ReportFile 'inventory.xlsx'

        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $ReportFile -eq 'inventory.xlsx' -and
            $TableName -eq 'Inventory' -and
            $WorksheetName -eq 'Inventory' -and
            $InputObject.Rows.Count -eq 4 -and
            $InputObject.Rows[0].Storage -eq 'oceanstor.test' -and
            $InputObject.Rows[2].Id -eq 'disk-01'
        }
    }

    It 'retrieves storage by hostname before exporting inventory' {
        $storage = [pscustomobject]@{
            Hostname = 'oceanstor.test'
            Enclosures = @()
            Controllers = @()
            disks = @()
            InterfaceModules = @()
        }
        Mock Export-DeviceManager { $storage }

        Export-DMInventory -Hostname 'oceanstor.test' -ReportFile 'inventory.xlsx'

        Should -Invoke Export-DeviceManager -Times 1 -Exactly -ParameterFilter { $Hostname -eq 'oceanstor.test' }
        Should -Invoke Export-Excel -Times 1 -Exactly
    }

    It 'exports all supported worksheets for a full version 6 storage report' {
        $storage = [pscustomobject]@{
            system             = [pscustomobject]@{ version = 'V600R001' }
            NtpServer          = [pscustomobject]@{ Enabled = $true }
            NtpStatus          = [pscustomobject]@{ Status = 'Synchronized' }
            SnmpConfig         = [pscustomobject]@{ Version = '3' }
            SnmpSecurityPolicy = [pscustomobject]@{ Strategy = '1' }
            SnmpTrapServers    = @([pscustomobject]@{ Address = '192.0.2.10' })
            SnmpUsmUsers       = @([pscustomobject]@{ Name = 'usm01' })
            SyslogNotification = [pscustomobject]@{ Enabled = $true }
            LocalUsers         = @([pscustomobject]@{ Name = 'admin' })
            Roles              = @([pscustomobject]@{ Name = 'Auditor' })
            RolePermissions    = @([pscustomobject]@{ Name = 'Read' })
            disks              = @('disk-01')
            StoragePools       = @('pool-01')
            LunGroups          = @('lungroup-01')
            luns               = @('lun-01')
            hostgroups         = @('hostgroup-01')
            hosts              = @('host-01')
            vStores            = @('vstore-01')
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject full -ReportFile 'configuration.xlsx'

        Should -Invoke Export-Excel -Times 18 -Exactly
        foreach ($expectedTable in @(
            'System', 'NtpServer', 'NtpStatus', 'SnmpConfig', 'SnmpSecurityPolicy',
            'SnmpTrapServers', 'SnmpUsmUsers', 'SyslogNotification', 'LocalUsers',
            'Roles', 'RolePermissions', 'Disks', 'StoragePools', 'LunGroups',
            'Luns', 'HostGroups', 'Hosts', 'vStores'
        )) {
            Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
                $ReportFile -eq 'configuration.xlsx' -and $TableName -eq $expectedTable
            }
        }
        Should -Invoke New-DMObjectReport -Times 1 -Exactly -ParameterFilter {
            $ReportType -eq 'lunsv6' -and $Object[0] -eq 'lun-01'
        }
    }

    It 'exports only requested worksheets and selects the version 3 LUN template' {
        $storage = [pscustomobject]@{
            system = [pscustomobject]@{ version = 'V300R006' }
            luns   = @('lun-03')
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject system, luns -ReportFile 'selected.xlsx'

        Should -Invoke Export-Excel -Times 2 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter { $TableName -eq 'System' }
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter { $TableName -eq 'Luns' }
        Should -Invoke New-DMObjectReport -Times 1 -Exactly -ParameterFilter {
            $ReportType -eq 'lunsv3' -and $Object[0] -eq 'lun-03'
        }
    }

    It 'exports only system configuration worksheets when requested' {
        $storage = [pscustomobject]@{
            system             = [pscustomobject]@{ version = 'V600R001' }
            NtpServer          = [pscustomobject]@{ Enabled = $true }
            NtpStatus          = [pscustomobject]@{ Status = 'Synchronized' }
            SnmpConfig         = [pscustomobject]@{ Version = '3' }
            SnmpSecurityPolicy = [pscustomobject]@{ Strategy = '1' }
            SnmpTrapServers    = @([pscustomobject]@{ Address = '192.0.2.10' })
            SnmpUsmUsers       = @([pscustomobject]@{ Name = 'usm01' })
            SyslogNotification = [pscustomobject]@{ Enabled = $true }
            LocalUsers         = @([pscustomobject]@{ Name = 'admin' })
            Roles              = @([pscustomobject]@{ Name = 'Auditor' })
            RolePermissions    = @([pscustomobject]@{ Name = 'Read' })
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject configuration -ReportFile 'configuration.xlsx'

        Should -Invoke Export-Excel -Times 10 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'NtpServer' -and $WorksheetName -eq 'NTP Server'
        }
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'LocalUsers' -and $WorksheetName -eq 'Local Users'
        }
        Should -Invoke New-DMObjectReport -Times 0 -Exactly
    }

    It 'exports one worksheet per performance section with joined object names' {
        $storage = [pscustomobject]@{
            system       = [pscustomobject]@{ version = 'V600R001' }
            Session      = [pscustomobject]@{ Token = 'sess-01' }
            Controllers  = @([pscustomobject]@{ Id = 'ctrl-01'; Name = 'ctrl0' })
            StoragePools = @([pscustomobject]@{ Id = 'pool-01'; Name = 'pool0' })
            disks        = @([pscustomobject]@{ Id = 'disk-01'; Name = 'disk0' })
            hosts        = @([pscustomobject]@{ Id = 'host-01'; Name = 'host0' })
            luns         = @([pscustomobject]@{ Id = 'lun-01'; Name = 'lun0' })
        }
        Mock Get-DMControllerPerformance { [pscustomobject]@{ ObjectId = 'ctrl-01'; IOPS = 100 } }
        Mock Get-DMStoragePoolPerformance { [pscustomobject]@{ ObjectId = 'pool-01'; IOPS = 200 } }
        Mock Get-DMDiskPerformance { [pscustomobject]@{ ObjectId = 'disk-01'; IOPS = 300 } }
        Mock Get-DMHostPerformance { [pscustomobject]@{ ObjectId = 'host-01'; IOPS = 400 } }
        Mock Get-DMLunPerformance { [pscustomobject]@{ ObjectId = 'lun-01'; IOPS = 500 } }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -ReportFile 'performance.xlsx'

        Should -Invoke Export-Excel -Times 5 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'ControllerPerformance' -and $WorksheetName -eq 'Controller Performance' -and $InputObject.ObjectName -eq 'ctrl0'
        }
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'StoragePoolPerformance' -and $WorksheetName -eq 'Storage Pool Performance' -and $InputObject.ObjectName -eq 'pool0'
        }
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'DiskPerformance' -and $WorksheetName -eq 'Disk Performance' -and $InputObject.ObjectName -eq 'disk0'
        }
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'HostPerformance' -and $WorksheetName -eq 'Host Performance' -and $InputObject.ObjectName -eq 'host0'
        }
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'LunPerformance' -and $WorksheetName -eq 'LUN Performance' -and $InputObject.ObjectName -eq 'lun0'
        }
    }

    It 'does not query performance wrappers when -IncludeObject full is used' {
        $storage = [pscustomobject]@{
            system       = [pscustomobject]@{ version = 'V600R001' }
            disks        = @('disk-01')
            StoragePools = @('pool-01')
            luns         = @('lun-01')
            hosts        = @('host-01')
            hostgroups   = @('hostgroup-01')
            LunGroups    = @('lungroup-01')
            vStores      = @('vstore-01')
            Controllers  = @([pscustomobject]@{ Id = 'ctrl-01'; Name = 'ctrl0' })
            Session      = [pscustomobject]@{ Token = 'sess-01' }
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject full -ReportFile 'full.xlsx'

        Should -Invoke Get-DMSystemPerformance -Times 0 -Exactly
        Should -Invoke Get-DMControllerPerformance -Times 0 -Exactly
        Should -Invoke Get-DMStoragePoolPerformance -Times 0 -Exactly
        Should -Invoke Get-DMDiskPerformance -Times 0 -Exactly
        Should -Invoke Get-DMHostPerformance -Times 0 -Exactly
        Should -Invoke Get-DMLunPerformance -Times 0 -Exactly
        Should -Invoke Export-Excel -Times 0 -Exactly -ParameterFilter { $TableName -like '*Performance' }
    }

    It 'skips a capped performance section beyond the object cap but still exports uncapped and within-cap sections' {
        $manyControllers = 1..501 | ForEach-Object { [pscustomobject]@{ Id = "ctrl-$_"; Name = "ctrl$_" } }
        $manyDisks = 1..501 | ForEach-Object { [pscustomobject]@{ Id = "disk-$_"; Name = "disk$_" } }
        $storage = [pscustomobject]@{
            system      = [pscustomobject]@{ version = 'V600R001' }
            Session     = [pscustomobject]@{ Token = 'sess-01' }
            Controllers = $manyControllers
            disks       = $manyDisks
            hosts       = @([pscustomobject]@{ Id = 'host-01'; Name = 'host0' })
        }
        Mock Get-DMControllerPerformance { [pscustomobject]@{ ObjectId = 'ctrl-1'; IOPS = 1 } }
        Mock Get-DMHostPerformance { [pscustomobject]@{ ObjectId = 'host-01'; IOPS = 1 } }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -ReportFile 'cap.xlsx' -WarningAction SilentlyContinue -WarningVariable capWarnings

        Should -Invoke Get-DMDiskPerformance -Times 0 -Exactly
        Should -Invoke Export-Excel -Times 0 -Exactly -ParameterFilter { $TableName -eq 'DiskPerformance' }
        $capWarnings.Count | Should -BeGreaterThan 0
        ($capWarnings -join ' ') | Should -Match 'DiskPerformance'

        Should -Invoke Get-DMControllerPerformance
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter { $TableName -eq 'ControllerPerformance' }

        Should -Invoke Get-DMHostPerformance -Times 1 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter { $TableName -eq 'HostPerformance' }
    }

    It 'limits LUN performance export to the first 25 LUNs by default instead of skipping all LUN performance' {
        $manyLuns = 1..501 | ForEach-Object { [pscustomobject]@{ Id = "lun-$_"; Name = "lun$_" } }
        $storage = [pscustomobject]@{
            system = [pscustomobject]@{ version = 'V600R001' }
            Session = [pscustomobject]@{ Token = 'sess-01' }
            luns = $manyLuns
        }
        $script:lunPerfCall = 0
        Mock Get-DMLunPerformance {
            $script:lunPerfCall++
            [pscustomobject]@{ ObjectId = "lun-$script:lunPerfCall"; IOPS = 1 }
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -ReportFile 'lun-limit.xlsx' -WarningAction SilentlyContinue -WarningVariable lunWarnings

        Should -Invoke Get-DMLunPerformance -Times 25 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'LunPerformance' -and @($InputObject).Count -eq 25 -and
            @($InputObject)[0].ObjectId -eq 'lun-1' -and @($InputObject)[24].ObjectId -eq 'lun-25'
        }
        ($lunWarnings -join ' ') | Should -Match 'limited to first 25 of 501 LUNs'
        ($lunWarnings -join ' ') | Should -Match 'PerformanceLunLimit'
    }

    It 'applies the default LUN performance export limit even below the legacy object cap' {
        $manyLuns = 1..30 | ForEach-Object { [pscustomobject]@{ Id = "lun-$_"; Name = "lun$_" } }
        $storage = [pscustomobject]@{
            system = [pscustomobject]@{ version = 'V600R001' }
            Session = [pscustomobject]@{ Token = 'sess-01' }
            luns = $manyLuns
        }
        $script:lunPerfCall = 0
        Mock Get-DMLunPerformance {
            $script:lunPerfCall++
            [pscustomobject]@{ ObjectId = "lun-$script:lunPerfCall"; IOPS = 1 }
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -ReportFile 'lun-limit-small.xlsx' -WarningAction SilentlyContinue -WarningVariable lunWarnings

        Should -Invoke Get-DMLunPerformance -Times 25 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'LunPerformance' -and @($InputObject).Count -eq 25
        }
        ($lunWarnings -join ' ') | Should -Match 'limited to first 25 of 30 LUNs'
    }

    It 'uses the user supplied LUN performance export limit' {
        $manyLuns = 1..501 | ForEach-Object { [pscustomobject]@{ Id = "lun-$_"; Name = "lun$_" } }
        $storage = [pscustomobject]@{
            system = [pscustomobject]@{ version = 'V600R001' }
            Session = [pscustomobject]@{ Token = 'sess-01' }
            luns = $manyLuns
        }
        $script:lunPerfCall = 0
        Mock Get-DMLunPerformance {
            $script:lunPerfCall++
            [pscustomobject]@{ ObjectId = "lun-$script:lunPerfCall"; IOPS = 1 }
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -ReportFile 'lun-limit-custom.xlsx' -PerformanceLunLimit 100 -WarningAction SilentlyContinue -WarningVariable lunWarnings

        Should -Invoke Get-DMLunPerformance -Times 100 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'LunPerformance' -and @($InputObject).Count -eq 100 -and
            @($InputObject)[99].ObjectId -eq 'lun-100'
        }
        ($lunWarnings -join ' ') | Should -Match 'limited to first 100 of 501 LUNs'
    }

    It 'allows unlimited LUN performance export when PerformanceLunLimit is zero' {
        $manyLuns = 1..501 | ForEach-Object { [pscustomobject]@{ Id = "lun-$_"; Name = "lun$_" } }
        $storage = [pscustomobject]@{
            system = [pscustomobject]@{ version = 'V600R001' }
            Session = [pscustomobject]@{ Token = 'sess-01' }
            luns = $manyLuns
        }
        $script:lunPerfCall = 0
        Mock Get-DMLunPerformance {
            $script:lunPerfCall++
            [pscustomobject]@{ ObjectId = "lun-$script:lunPerfCall"; IOPS = 1 }
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -ReportFile 'lun-limit-none.xlsx' -PerformanceLunLimit 0 -WarningAction SilentlyContinue -WarningVariable lunWarnings

        Should -Invoke Get-DMLunPerformance -Times 501 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'LunPerformance' -and @($InputObject).Count -eq 501
        }
        $lunWarnings | Should -BeNullOrEmpty
    }

    It 'exports system performance without requiring a name join' {
        $storage = [pscustomobject]@{
            Session = [pscustomobject]@{ Token = 'sess-01' }
            system  = [pscustomobject]@{ version = 'V600R001'; sn = 'SN12345' }
        }
        Mock Get-DMSystemPerformance { [pscustomobject]@{ ObjectId = 'SN12345'; IOPS = 42 } }

        { Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -ReportFile 'system.xlsx' } | Should -Not -Throw

        Should -Invoke Get-DMSystemPerformance -Times 1 -Exactly
        Should -Invoke Export-Excel -Times 1 -Exactly -ParameterFilter {
            $TableName -eq 'SystemPerformance' -and $WorksheetName -eq 'System Performance' -and
            $InputObject.ObjectId -eq 'SN12345' -and
            ($InputObject.PSObject.Properties.Name -notcontains 'ObjectName')
        }
    }
}
}
