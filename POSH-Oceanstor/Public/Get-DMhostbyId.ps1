function Get-DMhostbyId {
    <#
.SYNOPSIS
    Deprecated. To Get Huawei Oceanstor Storage configured Hosts querying by Hostid

.DESCRIPTION
    Deprecated - use Get-DMhost -Id instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.PARAMETER HostId
		Mandatory parameter [string], to set the Host ID to look for.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession and provide hostId by property name.

.OUTPUTS
    OceanStorHost

    Returns host objects whose ID matches the supplied hostId value.

.EXAMPLE

    PS C:\> Get-DMhostbyId -webSession $session -hostId 1

    OR

    PS C:\> $hosts = Get-DMhostbyId -hostId 1

.NOTES
    Filename: Get-DMhostbyId.ps1
    Deprecated: use Get-DMhost -Id instead.

.LINK
#>
    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [string]$hostId
    )

    Write-Warning "Get-DMhostbyId is deprecated and will be removed in a future release. Use Get-DMhost -Id instead."

    Get-DMhost -WebSession $WebSession -Id $hostId
}

Set-Alias -Name Get-DMhostsbyId -Value Get-DMhostbyId
