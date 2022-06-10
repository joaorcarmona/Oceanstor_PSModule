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
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true,ParameterSetName="NewConnection")]
			[String]$Hostname,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true,ParameterSetName="CurrentConnection")]
			[PSCustomObject]$OceanStor,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
			[string]$ReportFile
	)

	if ($hostname -ne "")
	{
		$storage = export-DeviceManager -Hostname $Hostname
	} else {
		$storage = $OceanStor
	}

	#TODO Use SaveFileDialog Form to select file

	$lunsReport = new-DMObjectReport -Object $storage.luns -ReportType luns
	$hostsReport = new-DMObjectReport -Object $storage.hosts -ReportType hosts

	Export-Excel $ReportFile -AutoSize -TableName System -InputObject $storage.system -WorksheetName "Basic System"
	Export-Excel $ReportFile -AutoSize -TableName Disks -InputObject $storage.disks -WorksheetName "System Disks"
	Export-Excel $ReportFile -AutoSize -TableName StoragePools -InputObject $storage.StoragePools -WorksheetName "Storage Pools"
	Export-Excel $ReportFile -AutoSize -TableName Luns -InputObject $lunsReport -WorksheetName "Luns"
	Export-Excel $ReportFile -AutoSize -TableName LunGroups -InputObject $storage.LunGroups -WorksheetName "Lun Groups"
	Export-Excel $ReportFile -AutoSize -TableName Hosts -InputObject $hostsReport -WorksheetName "Hosts"
	Export-Excel $ReportFile -AutoSize -TableName HostGroups -InputObject $storage.HostGroups -WorksheetName "Hosts Groups"
	Export-Excel $ReportFile -AutoSize -TableName vStores -InputObject $storage.vStores -WorksheetName "System vStores"

}