$script:DMPerformanceExcelObjectCap = 500
$script:DMPerformanceExcelDefaultLunLimit = 25

function Export-DMStorageToExcel {
    <#
	.SYNOPSIS
		Function that exports to Excel a Huawei Storage Device Configuration

	.DESCRIPTION
		Function that exports to Excel a Huawei Storage Device Configuration.
		The configuration to export can be supplied as an OceanStor object or collected by hostname.

	.PARAMETER Hostname
		Hostname or IP address of the Huawei OceanStor array when collecting a fresh export.
	.PARAMETER OceanStor
		Existing OceanStor storage object to use instead of collecting a fresh export.
	.PARAMETER ReportFile
		File path where the Excel configuration report is written.
	.PARAMETER IncludeObject
		Choose the report sections to include ("luns","system","configuration","hostgroups","lungroups","disks","hosts","vstores","storagepools","performance","full"). Multiple items are allowed. "performance" is opt-in only (not implied by "full") and pulls one live realtime sample per object type (System, Controllers, StoragePools, Disks, Hosts, LUNs) using the storage object's cached session.
	.PARAMETER PerformanceLunLimit
		Maximum number of LUNs to sample for the opt-in performance Excel section. Defaults to 25. The limit uses the first LUNs already present in the supplied storage inventory; use Get-DMLunPerformance directly for true top-busy LUN analysis. Set to 0 for no LUN limit.

	.INPUTS
		System.String
		System.Management.Automation.PSCustomObject

		You can pipe a hostname to Hostname or an exported OceanStor object to OceanStor.

	.OUTPUTS
		None

		Writes an Excel configuration workbook to ReportFile.

	.EXAMPLE

		PS C:\> Export-DMStorageToExcel -hostname storage.domain.tld -ReportFile "c:\temp\StorageReport.xlsx" IncludeObject full

		PS C:\> Export-DMStorageToExcel -OceanStor $StorageDevice -ReportFile "c:\temp\StorageReport.xlsx" IncludeObject system, luns

	.NOTES
		Filename: Export-DMStorageToExcel.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 0,
            Mandatory = $true,
            ParameterSetName = "NewConnection",
            HelpMessage = 'Enter a Storage IP or FQDN.')]
        [Alias("Storage")]
        [String]$Hostname,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true, ParameterSetName = "CurrentConnection")]
        [PSCustomObject]$OceanStor,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 2, Mandatory = $true)]
        [ValidateSet("luns", "system", "configuration", "hostgroups", "lungroups", "disks", "hosts", "vstores", "storagepools", "performance", "full")]
        [string[]]$IncludeObject,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 3, Mandatory = $true)]
        [string]$ReportFile,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$PerformanceLunLimit = $script:DMPerformanceExcelDefaultLunLimit
    )

    if ($hostname -ne "") {
        $storage = Export-DeviceManager -Hostname $Hostname
    }
    else {
        $storage = $OceanStor
    }

    $storageVersion = $storage.system.version.Substring(0, 2)

    #TODO Use SaveFileDialog Form to select file

    if ($IncludeObject -eq "full") {
        $IncludeLuns = $true
        $IncludeHosts = $true
        $IncludeSystem = $true
        $IncludeDisks = $true
        $IncludeStoragePools = $true
        $IncludeLunGroups = $true
        $IncludeHostGroups = $true
        $IncludevStore = $true
        $IncludeConfiguration = $true
    }
    else {
        $reportObject = $IncludeObject | Get-Unique
        foreach ($reportObj in $reportObject) {
            switch ($reportObj) {
                luns {
                    $IncludeLuns = $true
                }
                lungroups {
                    $IncludeLunGroups = $true
                }
                system {
                    $IncludeSystem = $true
                }
                configuration {
                    $IncludeConfiguration = $true
                }
                hosts {
                    $IncludeHosts = $true
                }
                hostgroups {
                    $IncludeHostGroups = $true
                }
                disks {
                    $IncludeDisks = $true
                }
                vstores {
                    $IncludevStore = $true
                }
                storagepools {
                    $IncludeStoragePools = $true
                }
                performance {
                    $IncludePerformance = $true
                }
            }
        }
    }


    #1) Adding System Report
    if ($IncludeSystem -eq $true) {
        Export-Excel $ReportFile -AutoSize -TableName System -InputObject $storage.system -WorksheetName "Basic System"
    }

    #1.1) Adding system configuration reports
    if ($IncludeConfiguration -eq $true) {
        $configurationSections = @(
            @{ TableName = 'NtpServer'; InputObject = $storage.NtpServer; WorksheetName = 'NTP Server' }
            @{ TableName = 'NtpStatus'; InputObject = $storage.NtpStatus; WorksheetName = 'NTP Status' }
            @{ TableName = 'SnmpConfig'; InputObject = $storage.SnmpConfig; WorksheetName = 'SNMP Config' }
            @{ TableName = 'SnmpSecurityPolicy'; InputObject = $storage.SnmpSecurityPolicy; WorksheetName = 'SNMP Security' }
            @{ TableName = 'SnmpTrapServers'; InputObject = $storage.SnmpTrapServers; WorksheetName = 'SNMP Trap Servers' }
            @{ TableName = 'SnmpUsmUsers'; InputObject = $storage.SnmpUsmUsers; WorksheetName = 'SNMP USM Users' }
            @{ TableName = 'SyslogNotification'; InputObject = $storage.SyslogNotification; WorksheetName = 'Syslog Notification' }
            @{ TableName = 'LocalUsers'; InputObject = $storage.LocalUsers; WorksheetName = 'Local Users' }
            @{ TableName = 'Roles'; InputObject = $storage.Roles; WorksheetName = 'Roles' }
            @{ TableName = 'RolePermissions'; InputObject = $storage.RolePermissions; WorksheetName = 'Role Permissions' }
        )

        foreach ($section in $configurationSections) {
            if ($null -ne $section.InputObject) {
                Export-Excel $ReportFile -AutoSize -TableName $section.TableName -InputObject $section.InputObject -WorksheetName $section.WorksheetName
            }
        }
    }

    #2) adding Disks
    if ($IncludeDisks -eq $true) {
        $DiskReport = New-DMObjectReport -Object $storage.disks -ReportType disks
        Export-Excel $ReportFile -AutoSize -TableName Disks -InputObject $DiskReport -WorksheetName "System Disks"
    }

    #3) Adding Storage Pools
    if ($IncludeStoragePools -eq $true) {
        Export-Excel $ReportFile -AutoSize -TableName StoragePools -InputObject $storage.StoragePools -WorksheetName "Storage Pools"
    }

    #4) Adding Lun Groups
    if ($IncludeLunGroups -eq $true) {
        $LunGroupsReport = New-DMObjectReport -Object $storage.LunGroups -ReportType lungroups
        Export-Excel $ReportFile -AutoSize -TableName LunGroups -InputObject $LunGroupsReport -WorksheetName "Lun Groups"
    }

    #5) Adding LUNs
    if ($IncludeLuns -eq $true) {
        if ($storageVersion -eq "V3") {
            $reportLunsVersion = "lunsv3"
        }
        elseif ($storageVersion -eq "V6") {
            $reportLunsVersion = "lunsv6"
        }

        $lunsReport = New-DMObjectReport -Object $storage.luns -ReportType $reportLunsVersion
        Export-Excel $ReportFile -AutoSize -TableName Luns -InputObject $lunsReport -WorksheetName "Luns"
    }

    #6) Adding LUN Groups
    if ($IncludeHostGroups -eq $true) {
        $hostGroupsReport = New-DMObjectReport -Object $storage.hostgroups -ReportType hostgroups
        Export-Excel $ReportFile -AutoSize -TableName HostGroups -InputObject $hostGroupsReport -WorksheetName "Host Groups"
    }

    #7) Adding Hosts
    if ($IncludeHosts -eq $true) {
        $hostsReport = New-DMObjectReport -Object $storage.hosts -ReportType hosts
        Export-Excel $ReportFile -AutoSize -TableName Hosts -InputObject $hostsReport -WorksheetName "Hosts"
    }

    #8) Adding vStores
    if ($IncludevStore -eq $true) {
        Export-Excel $ReportFile -AutoSize -TableName vStores -InputObject $storage.vStores -WorksheetName "System vStores"
    }

    #9) Adding Performance samples (opt-in only, never part of full)
    if ($IncludePerformance -eq $true) {
        $session = $storage.Session

        $systemPerf = Get-DMSystemPerformance -WebSession $session
        if ($systemPerf) {
            Export-Excel $ReportFile -AutoSize -TableName SystemPerformance -InputObject $systemPerf -WorksheetName "System Performance"
        }

        $perfSections = @(
            @{ Source = $storage.Controllers; Wrapper = 'Get-DMControllerPerformance'; Table = 'ControllerPerformance'; Worksheet = 'Controller Performance'; Cap = $false }
            @{ Source = $storage.StoragePools; Wrapper = 'Get-DMStoragePoolPerformance'; Table = 'StoragePoolPerformance'; Worksheet = 'Storage Pool Performance'; Cap = $false }
            @{ Source = $storage.disks; Wrapper = 'Get-DMDiskPerformance'; Table = 'DiskPerformance'; Worksheet = 'Disk Performance'; Cap = $true }
            @{ Source = $storage.hosts; Wrapper = 'Get-DMHostPerformance'; Table = 'HostPerformance'; Worksheet = 'Host Performance'; Cap = $true }
            @{ Source = $storage.luns; Wrapper = 'Get-DMLunPerformance'; Table = 'LunPerformance'; Worksheet = 'LUN Performance'; Cap = $true }
        )

        foreach ($section in $perfSections) {
            $objects = @($section.Source)
            if ($objects.Count -eq 0) { continue }

            if ($section.Table -eq 'LunPerformance') {
                if ($PerformanceLunLimit -gt 0 -and $objects.Count -gt $PerformanceLunLimit) {
                    Write-Warning "LUN performance export limited to first $PerformanceLunLimit of $($objects.Count) LUNs. Use -PerformanceLunLimit to increase the limit, set it to 0 for no LUN limit, or use Get-DMLunPerformance directly for selected LUNs."
                    $objects = @($objects | Select-Object -First $PerformanceLunLimit)
                }
            }
            elseif ($section.Cap -and $objects.Count -gt $script:DMPerformanceExcelObjectCap) {
                Write-Warning "Skipping $($section.Table) performance: $($objects.Count) objects exceeds the $($script:DMPerformanceExcelObjectCap)-object cap. Use $($section.Wrapper) directly with a smaller selection if needed."
                continue
            }

            $samples = $objects | & $section.Wrapper -WebSession $session
            if (-not $samples) { continue }

            $namesById = @{}
            foreach ($obj in $objects) { $namesById[$obj.Id] = $obj.Name }
            foreach ($sample in $samples) {
                $sample | Add-Member -NotePropertyName ObjectName -NotePropertyValue $namesById[$sample.ObjectId] -Force
            }

            Export-Excel $ReportFile -AutoSize -TableName $section.Table -InputObject $samples -WorksheetName $section.Worksheet
        }
    }

    #TODO Adding MappingView
    #TODO Adding templates for the performance reports (charts, etc)
}
