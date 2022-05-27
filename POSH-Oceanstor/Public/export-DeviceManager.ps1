function export-DeviceManager{
	<#
	.SYNOPSIS
		Function that returns an OceanStor Storage Device with all the properties currently in the module.

	.DESCRIPTION
		Function that returns an OceanStor Storage Device with all the properties currently in the module.
		This object can be used to report or exported for documentation.
		Is an export all storage configuration

	.PARAMETER Hostname
		is mandatory [string] parameter, that can be a hostname or an IP Address of the Huawei Oceanstor Device

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Device object with all the configuration. Return a Custom object

	.EXAMPLE

		PS C:\> $storageExport = export-OceanstorStorage -hostname storage.domain.tld

	.NOTES
		Filename: export-DeviceManager.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
	Param(
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
			[String]$Hostname
	)

	$result = [OceanstorViewStorage]::new($Hostname)

	return $result
}