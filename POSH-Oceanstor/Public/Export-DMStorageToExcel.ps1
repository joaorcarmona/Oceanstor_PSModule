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
		Choose the report sections to include ("luns","system","hostgroups","lungroups","disks","hosts","vstores","storagepools","full"). Multiple items are allowed.

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
        [ValidateSet("luns", "system", "hostgroups", "lungroups", "disks", "hosts", "vstores", "storagepools", "full")]
        [string[]]$IncludeObject,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 3, Mandatory = $true)]
        [string]$ReportFile
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
            }
        }
    }


    #1) Adding System Report
    if ($IncludeSystem -eq $true) {
        Export-Excel $ReportFile -AutoSize -TableName System -InputObject $storage.system -WorksheetName "Basic System"
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

    #TODO Adding MappingView
}
