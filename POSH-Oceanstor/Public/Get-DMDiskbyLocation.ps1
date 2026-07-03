function Get-DMDiskbyLocation {
    <#
	.SYNOPSIS
		Deprecated. To Get Huawei Oceanstor Storage disks by the location

	.DESCRIPTION
		Deprecated - use Get-DMdisk -Location instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Location
		Mandatory parameter Location Enclosure/Slot (String), to search for a disk

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide Location by property name.

	.OUTPUTS
		OceanStorDisks

		Returns disk objects whose location matches the supplied Location value.
	.EXAMPLE

		PS C:\> Get-DMDiskbyLocation -webSession $session -Location DAE000.24

		OR

		PS C:\> $disks = Get-DMDiskbyLocation $session -Location DAE000.24

	.NOTES
		Filename: Get-DMDiskbyLocation.ps1
		Deprecated: use Get-DMdisk -Location instead.

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [pscustomobject]$location
    )

    Write-Warning "Get-DMDiskbyLocation is deprecated and will be removed in a future release. Use Get-DMdisk -Location instead."

    return Get-DMdisk -WebSession $WebSession -Location $location
}
