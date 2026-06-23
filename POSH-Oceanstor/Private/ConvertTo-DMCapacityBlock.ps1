function ConvertTo-DMCapacityBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object]$Capacity,

        [ValidateSet('Blocks', 'GB')]
        [string]$UnitlessUnit = 'Blocks'
    )

    $capacityText = ([string]$Capacity).Trim()
    $blockCount = [decimal]0

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

        $blocksPerUnit = switch ($Matches.Unit.ToUpperInvariant()) {
            'MB' { [decimal]2048 }
            'GB' { [decimal]2097152 }
            'TB' { [decimal]2147483648 }
        }
        $blockCount = $size * $blocksPerUnit
    }
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
            [decimal]$unitlessValue
        }
    }

    if ($blockCount -gt [long]::MaxValue) {
        throw "Capacity '$capacityText' exceeds the supported maximum."
    }
    if ([decimal]::Truncate($blockCount) -ne $blockCount) {
        throw "Capacity '$capacityText' does not resolve to a whole number of 512-byte blocks."
    }

    return [long]$blockCount
}
