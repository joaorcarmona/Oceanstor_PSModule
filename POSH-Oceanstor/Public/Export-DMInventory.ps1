function Export-DMInventory {
    <#
	.SYNOPSIS
		Function that exports to Excel a Huawei Storage Device Inventory

	.DESCRIPTION
		Function that exports to Excel a Huawei Storage Device Inventory.
		The configuration to export can be supplied as an OceanStor object or collected by hostname.

	.PARAMETER Hostname
		Hostname or IP address of the Huawei OceanStor array when collecting a fresh export.
	.PARAMETER OceanStor
		Existing OceanStor storage object to use instead of collecting a fresh export.
	.PARAMETER ReportFile
		File path where the Excel inventory report is written.

	.INPUTS
		System.String
		System.Management.Automation.PSCustomObject

		You can pipe a hostname to Hostname or an exported OceanStor object to OceanStor.

	.OUTPUTS
		None

		Writes an Excel inventory workbook to ReportFile.

	.EXAMPLE

		PS C:\> Export-DMInventory -hostname storage.domain.tld -ReportFile "c:\temp\StorageReport.xlsx"

		PS C:\> Export-DMInventory -OceanStor $StorageDevice -ReportFile "c:\temp\StorageReport.xlsx"

	.NOTES
		Filename: Export-DMInventory.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true, ParameterSetName = "NewConnection")]
        [String]$Hostname,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true, ParameterSetName = "CurrentConnection")]
        [PSCustomObject]$OceanStor,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [string]$ReportFile
    )

    if ($hostname -ne "") {
        $storage = Export-DeviceManager -Hostname $Hostname
    }
    else {
        $storage = $OceanStor
    }

    #TODO Use SaveFileDialog Form to select file

    $StorageInventory = $storage.Enclosures
    $StorageInventory += $storage.Controllers
    $StorageInventory += $storage.disks
    $StorageInventory += $storage.InterfaceModules

    #Define Inventory Table Header Array
    $headers = @("Storage", "Id"; "Name", "Part Number", "Serial Number", "Description")

    #Create Table Inventory
    $inventory = New-Object System.Data.Datatable

    #Add Columns to Inventory Table
    foreach ($head in $headers) {
        [void]$inventory.Columns.Add("$head")
    }

    #Add Enclosures to Inventory Table
    foreach ($item in $StorageInventory) {
        $InventoryRow = $inventory.NewRow()

        foreach ($header in $headers) {
            if ($header -eq "Storage") {
                $InventoryRow.Storage = $storage.Hostname
            }
            else {
                $InventoryRow.$header = $item.$header
            }
        }

        $Inventory.Rows.Add($InventoryRow)
    }

    Export-Excel $ReportFile -AutoSize -TableName Inventory -InputObject $inventory -WorksheetName "Inventory"
}
