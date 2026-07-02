function Get-DMHostFilterableProperty {
    <#
    .SYNOPSIS
        Lists the host property names that Get-DMhostbyFilter/Get-DMhostbyId/Get-DMhostbyName accept as -Filter.

    .DESCRIPTION
        Reflects on OceanStorHost's real, visible properties via Get-DMFilterableProperty,
        the same set Assert-DMValidFilterProperty checks -Filter against before Get-DMhostbyFilter
        makes any REST call. Useful to discover valid -Filter values directly, and this
        command exists as a public, exported wrapper specifically so it can also be
        called from Get-DMhostbyFilter's -Filter ArgumentCompleter: a PowerShell class
        type literal (or a call to an unexported private function) referenced directly
        inside an ArgumentCompleter attribute scriptblock does not reliably resolve when
        the real completion engine invokes it -- confirmed empirically that only calls to
        exported module functions work there.

    .OUTPUTS
        System.String[]

    .EXAMPLE
        PS C:\> Get-DMHostFilterableProperty

        Lists every property Get-DMhostbyFilter -Filter can be set to.

    .NOTES
        Filename: Get-DMHostFilterableProperty.ps1
    #>
    [Cmdletbinding()]
    [OutputType([System.String[]])]
    param()

    Get-DMFilterableProperty -Type ([OceanStorHost])
}
