function Get-DMfreeDisk {
    <#
	.SYNOPSIS
		Deprecated. To Get Huawei Oceanstor Storage free disks (not used)

	.DESCRIPTION
		Deprecated - use Get-DMdisk -Free instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorDisks

		Returns disk objects whose Disk Usage property is free.

	.EXAMPLE

		PS C:\> Get-DMfreeDisk -webSession $session

		OR

		PS C:\> $freeDisks = Get-DMfreeDisk

	.NOTES
		Filename: Get-DMfreeDisk.ps1
		Deprecated: use Get-DMdisk -Free instead.

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    Write-Warning "Get-DMfreeDisk is deprecated and will be removed in a future release. Use Get-DMdisk -Free instead."

    return Get-DMdisk -WebSession $WebSession -Free
}

Set-Alias -Name Get-DMfreeDisks -Value Get-DMfreeDisk
