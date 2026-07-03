function Get-DMlunByName {
    <#
    .SYNOPSIS
        Deprecated. Searches for a LUN by its name.

    .DESCRIPTION
        Deprecated - use Get-DMlun -Name instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Mandatory LUN name to search for. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession and provide name by property name.

    .OUTPUTS
        OceanstorLunv3
        OceanstorLunv6

        Returns LUN objects whose name matches the supplied value. The class depends on the connected OceanStor version.

    .EXAMPLE

        PS C:\> Get-DMlunByName -webSession $session -Name "finance"

        OR

        PS C:\> $luns = Get-DMlunByName -Name "finance"

        OR

        PS C:\> $luns = Get-DMlunByName -Name "finance*"

    .NOTES
        Filename: Get-DMlunByName.ps1
        Deprecated: use Get-DMlun -Name instead.

    .LINK
    #>
    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Write-Warning "Get-DMlunByName is deprecated and will be removed in a future release. Use Get-DMlun -Name instead."

    Get-DMlun -WebSession $WebSession -Name $Name
}

Set-Alias -Name Get-DMlunsByName -Value Get-DMlunByName
