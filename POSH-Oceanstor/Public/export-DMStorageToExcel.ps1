function export-DMStorageToExcel{
	<#
	.SYNOPSIS
		Function that exports to Excel a Huawei Storage Device Configuration

	.DESCRIPTION
		Function that exports to Excel a Huawei Storage Device Configuration.
		The Configuration to be exported can be by given an OceanstorStorage Object, or by inputing a hostname, and the function will retrive all information.

	.PARAMETER Hostname
		is mandatory/optional [string] parameter, that can be a hostname or an IP Address of the Huawei Oceanstor Device
	.PARAMETER OceanStor
		is mandatory/optional [pscustomObject] parameter. Is Huawei Oceanstor Device Object
	.PARAMETER ReportFile
		is a mandatory parameter, that sets the filepath to save the Excel File Report.

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Device object with all the configuration. Return a Custom object

	.EXAMPLE

		PS C:\> export-DMStorageToExcel -hostname storage.domain.tld -ReportFile "c:\temp\StorageReport.xlsx"

		PS C:\> export-DMStorageToExcel -OceanStor $StorageDevice -ReportFile "c:\temp\StorageReport.xlsx"

	.NOTES
		Filename: export-DMStorageToExcel.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
	Param(
		[Parameter(ValueFromPipeline=$True,
				ValueFromPipelineByPropertyName=$True,
				Position=0,
				Mandatory=$true,
				ParameterSetName="NewConnection",
				HelpMessage='Enter a Storage IP or FQDN.')]
        	[Alias("Storage")]
			[String]$Hostname,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=1,Mandatory=$true,ParameterSetName="CurrentConnection")]
			[PSCustomObject]$OceanStor,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$true)]
			[string]$ReportFile,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=3,Mandatory=$false)]
			[switch]$IncludeLuns = $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=4,Mandatory=$false)]
			[switch]$IncludeHosts = $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=5,Mandatory=$false)]
			[switch]$IncludeSystem = $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=6,Mandatory=$false)]
			[switch]$IncludeDisks = $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=7,Mandatory=$false)]
			[switch]$IncludeStoragePools = $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=8,Mandatory=$false)]
			[switch]$IncludeLunGroups= $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=9,Mandatory=$false)]
			[switch]$IncludeHostGroups= $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=10,Mandatory=$false)]
			[switch]$IncludevStore= $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=11,Mandatory=$false)]
			[switch]$FullReport= $false
)


	if ($hostname -ne "")
	{
		$storage = export-DeviceManager -Hostname $Hostname
	} else {
		$storage = $OceanStor
	}

	#TODO Use SaveFileDialog Form to select file

	if ($FullReport -eq $true)
	{
		$IncludeLuns = $True
		$IncludeHosts = $True
		$IncludeSystem = $True
		$IncludeDisks = $True
		$IncludeStoragePools = $true
		$IncludeLunGroups = $True
		$IncludeHostGroups = $True
		$IncludevStore = $True
		$storageVersion = $storage.system.version.Substring(0,2)
	}

	#1) Adding System Report
	if ($IncludeSystem -eq $True)
	{
		Export-Excel $ReportFile -AutoSize -TableName System -InputObject $storage.system -WorksheetName "Basic System"
	}

	#2) adding Disks
	if ($IncludeDisks -eq $True)
	{
		$DiskReport = new-DMObjectReport -Object $storage.disks -ReportType disks
		Export-Excel $ReportFile -AutoSize -TableName Disks -InputObject $DiskReport -WorksheetName "System Disks"
	}

	#3) Adding Storage Pools
	If ($IncludeStoragePools -eq $True)
	{
		Export-Excel $ReportFile -AutoSize -TableName StoragePools -InputObject $storage.StoragePools -WorksheetName "Storage Pools"
	}

	#4) Adding Lun Groups
	If ($IncludeLunGroups -eq $True)
	{
		$LunGroupsReport = new-DMObjectReport -Object $storage.LunGroups -ReportType lungroups
		Export-Excel $ReportFile -AutoSize -TableName LunGroups -InputObject $LunGroupsReport -WorksheetName "Lun Groups"
	}

	#5) Addings LUNs
	if ($IncludeLuns -eq $True)
	{
		if ($storageVersion -eq "V3")
		{
			$reportLunsVersion = "lunsv3"
		}
		elseif ($storageVersion -eq "V6")
		{
			$reportLunsVersion = "lunsv6"
		}

		$lunsReport = new-DMObjectReport -Object $storage.luns -ReportType $reportLunsVersion
		Export-Excel $ReportFile -AutoSize -TableName Luns -InputObject $lunsReport -WorksheetName "Luns"
	}

	#6) Adding LUN Groups
	if ($IncludeHostGroups -eq $True)
	{
		$hostGroupsReport = new-DMObjectReport -Object $storage.hostgroups -ReportType hostgroups
		Export-Excel $ReportFile -AutoSize -TableName HostGroups -InputObject $hostGroupsReport -WorksheetName "Host Groups"
	}

	#7) Adding Hosts
	if ($IncludeHosts -eq $True)
	{
		$hostsReport = new-DMObjectReport -Object $storage.hosts -ReportType hosts
		Export-Excel $ReportFile -AutoSize -TableName Hosts -InputObject $hostsReport -WorksheetName "Hosts"
	}

	#8) Adding vStores
	if ($IncludevStore -eq $true)
	{
		Export-Excel $ReportFile -AutoSize -TableName vStores -InputObject $storage.vStores -WorksheetName "System vStores"
	}

	#TODO Adding MappingView
	#remove after 
	return $LunGroupsReport
}