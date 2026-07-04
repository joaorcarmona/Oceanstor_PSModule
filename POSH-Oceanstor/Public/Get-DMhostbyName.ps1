function Get-DMhostbyName {
    <#
.SYNOPSIS
    Deprecated. To Get Huawei Oceanstor Storage configured Hosts querying by Host Name

.DESCRIPTION
    Deprecated - use Get-DMhost -Name instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.PARAMETER Name
		Mandatory parameter [string], to set the Host Name to look for.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession and provide Name by property name.

.OUTPUTS
    OceanStorHost

    Returns host objects whose name matches the supplied Name value.

.EXAMPLE

    PS C:\> Get-DMhostbyName -webSession $session -Name Host001

    OR

    PS C:\> $hosts = Get-DMhostbyName -Name Host001

.NOTES
    Filename: Get-DMhostbyName.ps1
    Deprecated: use Get-DMhost -Name instead.

.LINK
#>
    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [string]$Name
    )

    Write-Warning "Get-DMhostbyName is deprecated and will be removed in a future release. Use Get-DMhost -Name instead."

    Get-DMhost -WebSession $WebSession -Name $Name
}

Set-Alias -Name Get-DMhostsbyName -Value Get-DMhostbyName
