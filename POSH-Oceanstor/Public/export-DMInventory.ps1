function export-DMInventory{
	<#
	.SYNOPSIS
		Function that exports to Excel a Huawei Storage Device Inventory

	.DESCRIPTION
		Function that exports to Excel a Huawei Storage Device Inventory.
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

		PS C:\> export-DMInventory -hostname storage.domain.tld -ReportFile "c:\temp\StorageReport.xlsx"

		PS C:\> export-DMInventory -OceanStor $StorageDevice -ReportFile "c:\temp\StorageReport.xlsx"

	.NOTES
		Filename: export-DMInventory.ps1
		Author: Joao Carmona
		Modified date: 2022-06-02
		Version 0.1

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

	$storage.disks | select-object "type", Id, Name, "Part Number", "Serial Number", Description | Export-Excel $ReportFile -AutoSize -TableName "Inventory" -WorksheetName "Inventory"
	$storage.Enclosures | select-object "type", Id, Name, "Part Number", "Serial Number", Description | Export-Excel $ReportFile -AutoSize -TableName "Inventory" -WorksheetName "Inventory"
	$storage.Controllers | select-object "type", Id, Name, "Part Number", "Serial Number", Description | Export-Excel $ReportFile -AutoSize -TableName "Inventory" -WorksheetName "Inventory"

}