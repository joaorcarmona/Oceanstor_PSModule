function Get-DMFilterableProperty {
    <#
    .SYNOPSIS
        Returns the names of Type's public, non-hidden instance properties.

    .DESCRIPTION
        Reflects on Type's public instance properties and excludes any carrying
        PowerShell's HiddenAttribute (how a class's hidden keyword is represented
        at the CLR level), leaving exactly the property names Where-Object/
        Get-Member/tab-completion would show for a constructed instance. Used as
        the single, non-hardcoded source of truth for both validating -Filter
        (Assert-DMValidFilterProperty) and offering it as ArgumentCompleter
        candidates, so the valid set never needs separate maintenance in either
        place -- it's derived straight from whichever class is passed in.

    .PARAMETER Type
        The class to reflect on, e.g. [OceanStorHost].

    .NOTES
        Filename: Get-DMFilterableProperty.ps1
    #>
    param(
        [Parameter(Mandatory)]
        [type]$Type
    )

    $Type.GetProperties([System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Instance) |
        Where-Object { -not ($_.GetCustomAttributes($true) | Where-Object { $_.GetType().Name -eq 'HiddenAttribute' }) } |
        Select-Object -ExpandProperty Name
}
