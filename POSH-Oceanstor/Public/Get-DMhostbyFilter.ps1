function Get-DMhostbyFilter {
    <#
    .SYNOPSIS
        Deprecated. Searches for OceanStor hosts by a property filter.

    .DESCRIPTION
        Deprecated - use Get-DMhost -Filter -Value instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Filter
        Mandatory property name to filter against. Validated against OceanStorHost's actual properties before any REST call is made; an unrecognized name throws immediately.

    .PARAMETER Keyword
        Mandatory value to match against the chosen property. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession and provide filter values by property name.

    .OUTPUTS
        OceanStorHost

        Returns host objects matching the requested property filter and keyword.

    .EXAMPLE

        PS C:\> Get-DMhostbyFilter -WebSession $session -Filter Id -Keyword 'host-01'

        OR

        PS C:\> $hosts = Get-DMhostbyFilter -Filter Name -Keyword 'esx01'

        OR

        PS C:\> $hosts = Get-DMhostbyFilter -Filter Name -Keyword 'esx*'

    .NOTES
        Filename: Get-DMhostbyFilter.ps1
        Deprecated: use Get-DMhost -Filter -Value instead.

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
                (Get-DMhost -WebSession $session | Select-Object -First 1).PSObject.Properties.Name |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Filter,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Keyword
    )

    Write-Warning "Get-DMhostbyFilter is deprecated and will be removed in a future release. Use Get-DMhost -Filter -Value instead."

    Get-DMhost -WebSession $WebSession -Filter $Filter -Value $Keyword
}

Set-Alias -Name Get-DMhostsbyFilter -Value Get-DMhostbyFilter
