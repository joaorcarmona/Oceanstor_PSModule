function Get-DMcofferDisk {
    <#
	.SYNOPSIS
		Deprecated. To Get Huawei Oceanstor Storage System coffer disks

	.DESCRIPTION
		Deprecated - use Get-DMdisk -Coffer instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorDisks

		Returns disk objects where cofferDisk is true.

	.EXAMPLE

		PS C:\> Get-DMcofferDisk -webSession $session

		OR

		PS C:\> $cofferDisks = Get-DMcofferDisk

	.NOTES
		Filename: Get-DMcofferDisk.ps1
		Deprecated: use Get-DMdisk -Coffer instead.

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    Write-Warning "Get-DMcofferDisk is deprecated and will be removed in a future release. Use Get-DMdisk -Coffer instead."

    return Get-DMdisk -WebSession $WebSession -Coffer
}

Set-Alias -Name Get-DMcofferDisks -Value Get-DMcofferDisk
