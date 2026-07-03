function New-DMNamedObjectUpdate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Objects,
        [Parameter(Mandatory)][string]$CurrentName,
        [Parameter(Mandatory)][string]$EntityName,
        [Parameter(Mandatory)][string]$ResourceBase,
        [string]$NewName,
        [switch]$NewNameSpecified,
        [AllowEmptyString()][string]$Description,
        [switch]$DescriptionSpecified,
        [System.Collections.IDictionary]$ApiProperties,
        [string]$VstoreId,
        [string]$NameField = 'NAME',
        [string]$DescriptionField = 'DESCRIPTION'
    )

    if (-not $NewNameSpecified -and -not $DescriptionSpecified -and
        (-not $ApiProperties -or $ApiProperties.Count -eq 0)) {
        throw 'Specify NewName, Description, or at least one ApiProperties entry.'
    }

    $matchingItems = @($Objects | Where-Object Name -CEQ $CurrentName)
    if ($matchingItems.Count -ne 1) {
        if ($matchingItems.Count -gt 1) {
            throw "$EntityName name '$CurrentName' is ambiguous."
        }
        throw "Invalid $EntityName name '$CurrentName'. Valid values are: $($Objects.Name -join ', ')"
    }
    $item = $matchingItems[0]

    if ($NewNameSpecified -and $NewName -cne $CurrentName -and $Objects.Name -contains $NewName) {
        throw "A $EntityName named '$NewName' already exists."
    }

    $body = @{ ID = $item.Id }
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $apiName = ([string]$key).ToUpperInvariant()
            if ($apiName -in @('ID', 'NAME')) {
                throw "ApiProperties field '$key' is reserved. Use the corresponding command parameter."
            }
            $body[[string]$key] = $ApiProperties[$key]
        }
    }
    if ($NewNameSpecified) {
        $body[$NameField] = $NewName
    }
    if ($DescriptionSpecified) {
        $body[$DescriptionField] = $Description
    }

    $resource = "$ResourceBase/$($item.Id)"
    if ($VstoreId) {
        $resource += "?vstoreId=$([uri]::EscapeDataString($VstoreId))"
    }

    $actions = @()
    if ($NewNameSpecified) { $actions += "rename to '$NewName'" }
    if ($DescriptionSpecified) { $actions += 'change description' }
    if ($ApiProperties -and $ApiProperties.Count -gt 0) { $actions += 'modify API properties' }

    return [pscustomobject]@{
        Item     = $item
        Body     = $body
        Resource = $resource
        Action   = $actions -join ', '
    }
}
