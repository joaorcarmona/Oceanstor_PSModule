function Set-DMFileSystem {
    <#
    .SYNOPSIS
        Modifies an OceanStor file system.

    .DESCRIPTION
        Resolves a file system by name and updates it through the Huawei filesystem resource. Rename,
        capacity, and description are first-class parameters. ApiProperties can contain any additional
        fields supported by the connected array's file-system modification API and passes them through unchanged.

        ID, NAME, and CAPACITY are reserved ApiProperties fields; use FileSystemName, NewName, and Capacity.

        Accepts multiple file systems from the pipeline by property name. Each file system is
        modified independently: a failure (e.g. an invalid/ambiguous name, a name collision, or a
        REST error) is reported as a non-terminating error and does not stop the rest from being
        processed. NewName is not meaningful for a batch of more than one file system.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER FileSystemName
        Existing file-system name to modify.

    .PARAMETER NewName
        New file-system name.

    .PARAMETER Capacity
        New total capacity. Accepts MB, GB, or TB with a period or comma decimal separator. An integer
        without a suffix retains the module's historical behavior and is treated as gigabytes.

    .PARAMETER Description
        New file-system description. An empty string clears the description.

    .PARAMETER ApiProperties
        Additional Huawei file-system modification fields to send verbatim.

    .EXAMPLE
        PS> Set-DMFileSystem -FileSystemName 'documents' -NewName 'documents-prod' -WhatIf

    .EXAMPLE
        PS> Set-DMFileSystem -FileSystemName 'documents' -Capacity '1,5TB' -Confirm:$false

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object indicating success or failure of the modification.

    .EXAMPLE
        PS> Set-DMFileSystem -FileSystemName 'documents' -ApiProperties @{ CAPACITYTHRESHOLD = 85 }
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [string]$FileSystemName,

        [ValidateNotNullOrEmpty()]
        [string]$NewName,

        [ValidateNotNullOrEmpty()]
        [object]$Capacity,

        [AllowEmptyString()]
        [string]$Description,

        [System.Collections.IDictionary]$ApiProperties
    )

    begin {
        $hasChanges = $PSBoundParameters.ContainsKey('NewName') -or
            $PSBoundParameters.ContainsKey('Capacity') -or
            $PSBoundParameters.ContainsKey('Description') -or
            ($ApiProperties -and $ApiProperties.Count -gt 0)
        if (-not $hasChanges) {
            throw 'Specify NewName, Capacity, Description, or at least one ApiProperties entry.'
        }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $fileSystems = @(Get-DMFileSystem -WebSession $session)
            $matchingItems = @($fileSystems | Where-Object Name -CEQ $FileSystemName)
            if ($matchingItems.Count -ne 1) {
                if ($matchingItems.Count -gt 1) {
                    throw "FileSystemName '$FileSystemName' is ambiguous."
                }
                throw "Invalid FileSystemName '$FileSystemName'. Valid values are: $($fileSystems.Name -join ', ')"
            }
            $fileSystem = $matchingItems[0]

            if ($PSBoundParameters.ContainsKey('NewName') -and $NewName -cne $FileSystemName -and $fileSystems.Name -contains $NewName) {
                throw "A file system named '$NewName' already exists."
            }

            $body = @{ ID = $fileSystem.Id }
            if ($ApiProperties) {
                foreach ($key in $ApiProperties.Keys) {
                    $apiName = ([string]$key).ToUpperInvariant()
                    if ($apiName -in @('ID', 'NAME', 'CAPACITY')) {
                        throw "ApiProperties field '$key' is reserved. Use the corresponding command parameter."
                    }
                    $body[[string]$key] = $ApiProperties[$key]
                }
            }
            if ($PSBoundParameters.ContainsKey('NewName')) {
                $body.NAME = $NewName
            }
            if ($PSBoundParameters.ContainsKey('Description')) {
                $body.DESCRIPTION = $Description
            }
            if ($PSBoundParameters.ContainsKey('Capacity')) {
                $newCapacityBlocks = ConvertTo-DMCapacityBlock -Capacity $Capacity -UnitlessUnit GB
                if ($null -ne $fileSystem.PSObject.Properties['RealCapacity'] -and
                    $newCapacityBlocks -eq [long]$fileSystem.RealCapacity) {
                    throw "Requested capacity is already the current file-system capacity ($newCapacityBlocks blocks)."
                }
                $body.CAPACITY = $newCapacityBlocks
            }

            $actions = @()
            if ($PSBoundParameters.ContainsKey('NewName')) { $actions += "rename to '$NewName'" }
            if ($PSBoundParameters.ContainsKey('Capacity')) { $actions += "resize to $Capacity" }
            if ($PSBoundParameters.ContainsKey('Description')) { $actions += 'change description' }
            if ($ApiProperties -and $ApiProperties.Count -gt 0) { $actions += 'modify API properties' }
            if (-not $PSCmdlet.ShouldProcess($FileSystemName, ($actions -join ', '))) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "filesystem/$($fileSystem.Id)" -BodyData $body
            $response = $response | Assert-DMApiSuccess
            return $response.error
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
