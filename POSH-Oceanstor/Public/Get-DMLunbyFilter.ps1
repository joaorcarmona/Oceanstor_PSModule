function Get-DMLunbyFilter {
    <#
    .SYNOPSIS
        Deprecated. Searches for LUNs by a property filter.

    .DESCRIPTION
        Deprecated - use Get-DMlun -Filter -Value instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Filter
        Mandatory property name to filter against. Validated against the connected array's LUN class properties (OceanstorLunv3 or OceanstorLunv6, depending on array version) before any REST call is made; an unrecognized name throws immediately.

    .PARAMETER Keyword
        Mandatory value to match against the chosen property. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession and provide filter values by property name.

    .OUTPUTS
        OceanstorLunv3
        OceanstorLunv6

        Returns LUN objects matching the requested property filter and keyword.

    .EXAMPLE

        PS C:\> Get-DMLunbyFilter -webSession $session -Filter WWN -Keyword "6a08cf810075766e1efc050700000005"

        OR

        PS C:\> $luns = Get-DMLunbyFilter -Filter Name -Keyword "finance"

        OR

        PS C:\> $luns = Get-DMLunbyFilter -Filter Name -Keyword "finance*"

    .NOTES
        Filename: Get-DMLunbyFilter.ps1
        Deprecated: use Get-DMlun -Filter -Value instead.

    .LINK
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session | Select-Object -First 1).PSObject.Properties.Name |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Filter,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Keyword
    )

    Write-Warning "Get-DMLunbyFilter is deprecated and will be removed in a future release. Use Get-DMlun -Filter -Value instead."

    Get-DMlun -WebSession $WebSession -Filter $Filter -Value $Keyword
}

Set-Alias -Name Get-DMLunsbyFilter -Value Get-DMLunbyFilter
