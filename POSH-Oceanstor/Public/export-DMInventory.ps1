function export-DMInventory
{
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

	$StorageInventory = $storage.Enclosures
	$StorageInventory += $storage.Controllers
	$StorageInventory += $storage.disks

	#Define Inventory Table Header Array
	$headers = @("Storage","Id";"Name","Part Number","Serial Number","Description")

	#Create Table Inventory
 	$inventory = New-Object System.Data.Datatable

	 #Add Columns to Inventory Table
	foreach ($head in $headers)
	{
		[void]$inventory.Columns.Add("$head")
	}

	#Add Enclosures to Inventory Table
	foreach ($item in $StorageInventory)
	{
		$InventoryRow = $inventory.NewRow()

		foreach ($header in $headers)
		{
			if ($header -eq "Storage")
			{
				$InventoryRow.Storage = $storage.Hostname
			} else {
				$InventoryRow.$header = $item.$header
			}
		}

		$Inventory.Rows.Add($InventoryRow)
	}

	Export-Excel $ReportFile -AutoSize -TableName Inventory -InputObject $inventory -WorksheetName "Inventory"
}