function Set-DMLun {
    <#
    .SYNOPSIS
        Modifies a LUN on an OceanStor Dorado V6 API session.

    .DESCRIPTION
        Resolves a LUN by name and modifies its properties. Rename and description changes use the LUN
        resource, while capacity expansion uses the dedicated lun/expand action. LUN reduction is not
        supported. This command rejects sessions whose version does not begin with V6.

        ApiProperties can contain additional fields supported by the Huawei LUN modification API. Values
        are passed through unchanged. ID, NAME, and CAPACITY are reserved; use LunName, NewName, and Capacity.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The global deviceManager session is used by default.

    .PARAMETER LunName
        Existing LUN name to modify.

    .PARAMETER NewName
        New LUN name.

    .PARAMETER Capacity
        New total capacity. Accepts MB, GB, or TB with a period or comma decimal separator. An integer
        without a suffix is treated as a legacy count of 512-byte blocks.

    .PARAMETER Description
        New LUN description. An empty string clears the description.

    .PARAMETER ApiProperties
        Additional Huawei LUN modification fields to send verbatim.

    .EXAMPLE
        PS> Set-DMLun -LunName 'database' -NewName 'database-prod' -WhatIf

    .EXAMPLE
        PS> Set-DMLun -LunName 'database' -Capacity 2.5TB -Confirm:$false

    .EXAMPLE
        PS> Set-DMLun -LunName 'database' -ApiProperties @{ IOPRIORITY = 3 }
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [string]$LunName,

        [ValidateNotNullOrEmpty()]
        [string]$NewName,

        [ValidateNotNullOrEmpty()]
        [object]$Capacity,

        [AllowEmptyString()]
        [string]$Description,

        [System.Collections.IDictionary]$ApiProperties
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    if (-not $session -or [string]$session.version -notmatch '^V6') {
        $version = if ($session) { [string]$session.version } else { '<none>' }
        throw "Set-DMLun supports only OceanStor Dorado V6 API sessions. Connected version: $version."
    }

    $hasPropertyChanges = $PSBoundParameters.ContainsKey('NewName') -or
        $PSBoundParameters.ContainsKey('Description') -or
        ($ApiProperties -and $ApiProperties.Count -gt 0)
    $hasCapacityChange = $PSBoundParameters.ContainsKey('Capacity')
    if (-not $hasPropertyChanges -and -not $hasCapacityChange) {
        throw 'Specify NewName, Capacity, Description, or at least one ApiProperties entry.'
    }

    $luns = @(Get-DMlun -WebSession $session)
    $matchingItems = @($luns | Where-Object Name -CEQ $LunName)
    if ($matchingItems.Count -ne 1) {
        if ($matchingItems.Count -gt 1) {
            throw "LunName '$LunName' is ambiguous."
        }
        throw "Invalid LunName '$LunName'. Valid values are: $($luns.Name -join ', ')"
    }
    $lun = $matchingItems[0]

    if ($PSBoundParameters.ContainsKey('NewName') -and $NewName -cne $LunName -and $luns.Name -contains $NewName) {
        throw "A LUN named '$NewName' already exists."
    }

    $propertyBody = @{ ID = $lun.Id }
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $apiName = ([string]$key).ToUpperInvariant()
            if ($apiName -in @('ID', 'NAME', 'CAPACITY')) {
                throw "ApiProperties field '$key' is reserved. Use the corresponding command parameter."
            }
            $propertyBody[[string]$key] = $ApiProperties[$key]
        }
    }
    if ($PSBoundParameters.ContainsKey('NewName')) {
        $propertyBody.NAME = $NewName
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $propertyBody.DESCRIPTION = $Description
    }

    $newCapacityBlocks = $null
    if ($hasCapacityChange) {
        $newCapacityBlocks = ConvertTo-DMCapacityBlock -Capacity $Capacity -UnitlessUnit Blocks
        $currentCapacityBlocks = if ($null -ne $lun.PSObject.Properties['RealCapacity']) {
            [long]$lun.RealCapacity
        }
        else {
            [long]([decimal]$lun.'Lun Size' * [decimal]1GB / [decimal]$lun.'Sector Size')
        }
        if ($newCapacityBlocks -le $currentCapacityBlocks) {
            throw "LUN capacity can only be expanded. Requested $newCapacityBlocks blocks; current capacity is $currentCapacityBlocks blocks."
        }
    }

    $actions = @()
    if ($hasPropertyChanges) { $actions += 'modify properties' }
    if ($hasCapacityChange) { $actions += "expand to $Capacity" }
    if (-not $PSCmdlet.ShouldProcess($LunName, ($actions -join ' and '))) {
        return
    }

    $results = [System.Collections.Generic.List[object]]::new()
    if ($hasPropertyChanges) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "lun/$($lun.Id)" -BodyData $propertyBody
        $results.Add($response.error)
        if ($response.error.Code -ne 0) {
            return $results
        }
    }
    if ($hasCapacityChange) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'lun/expand' -BodyData @{
            ID       = $lun.Id
            CAPACITY = $newCapacityBlocks
        }
        $results.Add($response.error)
    }

    return $results
}
