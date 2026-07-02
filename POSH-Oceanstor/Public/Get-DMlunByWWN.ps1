function Get-DMlunByWWN {
    <#
    .SYNOPSIS
        Searches for a LUN by its WWN.

    .DESCRIPTION
        Searches for LUNs whose WWN matches the supplied value, via
        Get-DMLunbyFilter. WWN supports PowerShell wildcards (*, ?, [...]);
        without one, the comparison is an exact match.

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

    .LINK
    #>
    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WWN
    )

    Get-DMLunbyFilter -WebSession $WebSession -Filter 'WWN' -Keyword $WWN
}

Set-Alias -Name Get-DMlunsByWWN -Value Get-DMlunByWWN
