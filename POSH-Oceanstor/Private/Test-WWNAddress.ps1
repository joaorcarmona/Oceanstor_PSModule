function Test-WWNAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$WWN
    )

    if ($WWN -notmatch '^[0-9A-Fa-f]{16}$') {
        return $false
    }

    return $WWN -notmatch '^(0{16}|[Ff]{16})$'
}

Set-Alias -Name Validate-WWNAddress -Value Test-WWNAddress
