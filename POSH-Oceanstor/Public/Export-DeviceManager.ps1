function Export-DeviceManager {
    <#
	.SYNOPSIS
		Function that returns an OceanStor Storage Device with all the properties currently in the module.

	.DESCRIPTION
		Function that returns an OceanStor Storage Device with all the properties currently in the module.
		This object can be used to report or exported for documentation.
		Exports all storage configuration collected by the module.

	.PARAMETER Hostname
		Mandatory hostname or IP address of the Huawei OceanStor array.

	.INPUTS
		System.String

		You can pipe a storage hostname or IP address to Hostname.

	.OUTPUTS
		OceanstorViewStorage

		Returns an OceanStor storage view object with the configuration data collected by the module.

	.EXAMPLE

		PS C:\> $storageExport = Export-DeviceManager -Hostname storage.domain.tld

	.NOTES
		Filename: Export-DeviceManager.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $true)]
        [String]$Hostname
    )

    $result = [OceanstorViewStorage]::new($Hostname)

    return $result
}
