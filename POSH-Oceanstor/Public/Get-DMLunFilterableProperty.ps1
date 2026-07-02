function Get-DMLunFilterableProperty {
    <#
    .SYNOPSIS
        Lists the LUN property names that Get-DMLunbyFilter/Get-DMlunByName/Get-DMlunByWWN accept as -Filter.

    .DESCRIPTION
        Reflects on both OceanstorLunv6 and OceanstorLunv3's real, visible properties via
        Get-DMFilterableProperty and returns their union, since which class applies
        depends on the connected array's version -- Assert-DMValidFilterProperty still
        enforces the correct one at execution time. Useful to discover valid -Filter
        values directly, and this command exists as a public, exported wrapper
        specifically so it can also be called from Get-DMLunbyFilter's -Filter
        ArgumentCompleter: a PowerShell class type literal (or a call to an unexported
        private function) referenced directly inside an ArgumentCompleter attribute
        scriptblock does not reliably resolve when the real completion engine invokes
        it -- confirmed empirically that only calls to exported module functions work
        there.

    .OUTPUTS
        System.String[]

    .EXAMPLE
        PS C:\> Get-DMLunFilterableProperty

        Lists every property Get-DMLunbyFilter -Filter can be set to.

    .NOTES
        Filename: Get-DMLunFilterableProperty.ps1
    #>
    [Cmdletbinding()]
    [OutputType([System.String[]])]
    param()

    @((Get-DMFilterableProperty -Type ([OceanstorLunv6])) + (Get-DMFilterableProperty -Type ([OceanstorLunv3]))) |
        Sort-Object -Unique
}
