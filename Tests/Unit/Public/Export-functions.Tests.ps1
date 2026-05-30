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
            system       = [pscustomobject]@{ version = 'V600R001' }
            disks        = @('disk-01')
            StoragePools = @('pool-01')
            LunGroups    = @('lungroup-01')
            luns         = @('lun-01')
            hostgroups   = @('hostgroup-01')
            hosts        = @('host-01')
            vStores      = @('vstore-01')
        }

        Export-DMStorageToExcel -OceanStor $storage -IncludeObject full -ReportFile 'configuration.xlsx'

        Should -Invoke Export-Excel -Times 8 -Exactly
        foreach ($expectedTable in @('System', 'Disks', 'StoragePools', 'LunGroups', 'Luns', 'HostGroups', 'Hosts', 'vStores')) {
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
}
}
