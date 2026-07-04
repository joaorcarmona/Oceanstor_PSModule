function Test-DMNetworkAddress {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Address
    )

    if ([string]::IsNullOrWhiteSpace($Address)) {
        return $false
    }

    $parsedAddress = $null
    if ([System.Net.IPAddress]::TryParse($Address, [ref]$parsedAddress)) {
        return $true
    }

    if ($Address.Length -gt 253 -or $Address -match '\s' -or $Address -notmatch '\.') {
        return $false
    }

    $labels = $Address.TrimEnd('.').Split('.')
    foreach ($label in $labels) {
        if ($label.Length -lt 1 -or $label.Length -gt 63) { return $false }
        if ($label -notmatch '^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$') { return $false }
    }

    return $true
}

function Assert-DMNetworkAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address,

        [string]$ParameterName = 'Address'
    )

    if (-not (Test-DMNetworkAddress -Address $Address)) {
        throw "$ParameterName '$Address' must be an IPv4 address, IPv6 address, or fully qualified domain name."
    }
}
