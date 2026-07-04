function ConvertTo-DMQuotaByte {
    # Converts a capacity value (e.g. "500MB", "1,5TB", or a raw byte count)
    # into the byte count expected by the OceanStor FS_QUOTA API. Must resolve
    # to an integer multiple of 1,048,576 bytes (1 MiB) and be <= 16 PB.
    [CmdletBinding()]
    [OutputType([uint64])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object]$Capacity
    )

    $capacityText = ([string]$Capacity).Trim()
    $bytes = [decimal]0
    $maxBytes = [decimal]16 * 1024 * 1024 * 1024 * 1024 * 1024

    if ($capacityText -match '^(?<Value>(?:\d+(?:[.,]\d+)?|[.,]\d+))\s*(?<Unit>MB|GB|TB)$') {
        $size = [decimal]0
        $normalizedValue = $Matches.Value.Replace(',', '.')
        $parsed = [decimal]::TryParse(
            $normalizedValue,
            [Globalization.NumberStyles]::AllowDecimalPoint,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$size
        )
        if (-not $parsed -or $size -le 0) {
            throw "Capacity must be greater than zero. Received '$capacityText'."
        }

        $bytesPerUnit = switch ($Matches.Unit.ToUpperInvariant()) {
            'MB' { [decimal]1048576 }
            'GB' { [decimal]1073741824 }
            'TB' { [decimal]1099511627776 }
        }
        $bytes = $size * $bytesPerUnit
    }
    else {
        $unitlessValue = [uint64]0
        if (-not [uint64]::TryParse(
                $capacityText,
                [Globalization.NumberStyles]::Integer,
                [Globalization.CultureInfo]::InvariantCulture,
                [ref]$unitlessValue
            )) {
            throw "Invalid capacity '$capacityText'. Use a positive value followed by MB, GB, or TB (for example, 500MB), or a raw byte count."
        }
        if ($unitlessValue -le 0) {
            throw "Capacity must be greater than zero. Received '$capacityText'."
        }
        $bytes = [decimal]$unitlessValue
    }

    if ($bytes -gt $maxBytes) {
        throw "Capacity '$capacityText' exceeds the supported maximum of 16 PB."
    }
    if (($bytes % 1048576) -ne 0) {
        throw "Capacity '$capacityText' must resolve to a whole multiple of 1 MB (1,048,576 bytes)."
    }

    return [uint64]$bytes
}
