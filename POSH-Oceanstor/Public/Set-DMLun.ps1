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

        Accepts multiple LUNs from the pipeline by property name (e.g. Get-DMlun output, matching its Name
        property). Each LUN is resolved and modified independently: a failure modifying one LUN (e.g. an
        invalid/ambiguous name, a name collision, or a REST error) is reported as a non-terminating error
        and does not stop the remaining LUNs from being processed. NewName is not meaningful for a batch of
        more than one LUN, since every LUN would collide on the same new name after the first is renamed.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

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

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        System.Collections.Generic.List[System.Object]

        Returns a list of OceanStor API error objects, one per operation (property change and/or capacity expansion).

    .EXAMPLE
        PS> Set-DMLun -LunName 'database' -ApiProperties @{ IOPRIORITY = 3 }

    .EXAMPLE
        PS> Get-DMlun | Where-Object Name -Like 'temp-*' | Set-DMLun -Description 'Scheduled for review' -Confirm:$false

        Updates the description on every LUN whose name starts with temp-. A LUN that fails is reported as
        a non-terminating error; the rest are still processed.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
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

    begin {
        $hasPropertyChanges = $PSBoundParameters.ContainsKey('NewName') -or
            $PSBoundParameters.ContainsKey('Description') -or
            ($ApiProperties -and $ApiProperties.Count -gt 0)
        $hasCapacityChange = $PSBoundParameters.ContainsKey('Capacity')
        if (-not $hasPropertyChanges -and -not $hasCapacityChange) {
            throw 'Specify NewName, Capacity, Description, or at least one ApiProperties entry.'
        }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            if (-not $session -or [string]$session.version -notmatch '^V6') {
                $version = if ($session) { [string]$session.version } else { '<none>' }
                throw "Set-DMLun supports only OceanStor Dorado V6 API sessions. Connected version: $version."
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
                elseif ($null -ne $lun.PSObject.Properties['Lun Size (GB)']) {
                    [long]([decimal]$lun.'Lun Size (GB)' * [decimal]1GB / [decimal]$lun.'Sector Size')
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

            if ($hasPropertyChanges) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "lun/$($lun.Id)" -BodyData $propertyBody
                $response = $response | Assert-DMApiSuccess
                if ($response.error.Code -ne 0 -or -not $hasCapacityChange) {
                    return $response.error
                }
            }
            if ($hasCapacityChange) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'lun/expand' -BodyData @{
                    ID       = $lun.Id
                    CAPACITY = $newCapacityBlocks
                }
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
