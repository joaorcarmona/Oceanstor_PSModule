function ConvertTo-DMCapacityBlock {
    # Converts a capacity value (e.g. "10GB", "500MB", "2TB", or a raw number)
    # into 512-byte block counts expected by the OceanStor DeviceManager API.
    [CmdletBinding()]
    [OutputType([long])]
    param(
        # Capacity with optional unit suffix: "10GB", "500MB", "2TB", or a raw number.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object]$Capacity,

        # How to interpret a bare number with no unit suffix:
        #   'Blocks' (default) = already in 512-byte blocks
        #   'GB' = treat the number as gigabytes
        [ValidateSet('Blocks', 'GB')]
        [string]$UnitlessUnit = 'Blocks'
    )

    $capacityText = ([string]$Capacity).Trim()
    $blockCount = [decimal]0

    # --- Path 1: input has a recognized unit suffix (MB, GB, TB) ---
    if ($capacityText -match '^(?<Value>(?:\d+(?:[.,]\d+)?|[.,]\d+))\s*(?<Unit>MB|GB|TB)$') {
        # Normalize comma decimal separators to dots for culture-invariant parsing
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

        # 1 block = 512 bytes, so: MB = 2^20/2^9, GB = 2^30/2^9, TB = 2^40/2^9
        $blocksPerUnit = switch ($Matches.Unit.ToUpperInvariant()) {
            'MB' { [decimal]2048 }          # 1 MB  = 2,048 blocks
            'GB' { [decimal]2097152 }       # 1 GB  = 2,097,152 blocks
            'TB' { [decimal]2147483648 }    # 1 TB  = 2,147,483,648 blocks
        }
        $blockCount = $size * $blocksPerUnit
    }
    # --- Path 2: bare integer — interpretation depends on $UnitlessUnit ---
    else {
        $unitlessValue = [long]0
        if (-not [long]::TryParse(
                $capacityText,
                [Globalization.NumberStyles]::Integer,
                [Globalization.CultureInfo]::InvariantCulture,
                [ref]$unitlessValue
            )) {
            throw "Invalid capacity '$capacityText'. Use a positive value followed by MB, GB, or TB (for example, 10GB)."
        }
        if ($unitlessValue -le 0) {
            throw "Capacity must be greater than zero. Received '$capacityText'."
        }

        $blockCount = if ($UnitlessUnit -eq 'GB') {
            [decimal]$unitlessValue * [decimal]2097152
        }
        else {
            # Already in 512-byte blocks — pass through as-is
            [decimal]$unitlessValue
        }
    }

    # Guard: block count must fit in [long] and must be a whole number
    # (fractional blocks aren't valid for the API)
    if ($blockCount -gt [long]::MaxValue) {
        throw "Capacity '$capacityText' exceeds the supported maximum."
    }
    if ([decimal]::Truncate($blockCount) -ne $blockCount) {
        throw "Capacity '$capacityText' does not resolve to a whole number of 512-byte blocks."
    }

    return [long]$blockCount
}
