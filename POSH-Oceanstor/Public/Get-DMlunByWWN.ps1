function Get-DMlunByWWN {
    <#
    .SYNOPSIS
        Deprecated. Searches for a LUN by its WWN.

    .DESCRIPTION
        Deprecated - use Get-DMlun -WWN instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER WWN
        Mandatory LUN WWN to search for. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession and provide wwn by property name.

    .OUTPUTS
        OceanstorLunv3
        OceanstorLunv6

        Returns LUN objects whose WWN matches the supplied value. The class depends on the connected OceanStor version.

    .EXAMPLE

        PS C:\> Get-DMlunByWWN -webSession $session -wwn "6a08cf810075766e1efc050700000005"

        OR

        PS C:\> $luns = Get-DMlunByWWN -wwn "6a08cf810075766e1efc050700000005"

    .NOTES
        Filename: Get-DMlunByWWN.ps1
        Deprecated: use Get-DMlun -WWN instead.

    .LINK
    #>
    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WWN
    )

    Write-Warning "Get-DMlunByWWN is deprecated and will be removed in a future release. Use Get-DMlun -WWN instead."

    Get-DMlun -WebSession $WebSession -WWN $WWN
}

Set-Alias -Name Get-DMlunsByWWN -Value Get-DMlunByWWN
