function Rename-DMstoragePool {
    <#
    .SYNOPSIS
        Renames an OceanStor storage pool.

    .DESCRIPTION
        Renames a storage pool by resolving it to its ID and issuing a PUT that changes only the pool's
        NAME label. The pool to rename is selected either by its current name (-StoragePoolName) or by
        its ID (-StoragePoolId). No other pool attribute is touched: capacity, tiers, thresholds,
        container application, and every LUN/file-system placement on the pool are left unchanged, so a
        rename is fully reversible by renaming back to the original name.

        This command is the module's ONLY storage-pool mutation. Creating, deleting, resizing, or
        changing description/threshold/container fields of a pool are intentionally not implemented.

        A storage pool is shared infrastructure, so this command is high-impact by default and prompts
        for confirmation. The new name is validated against the OceanStor pool-name rule (letters,
        digits, underscores, hyphens, periods; length 1-255) and is rejected if it collides with an
        existing pool.

        Accepts multiple pools from the pipeline by property name. Each is processed independently: a
        failure (invalid/ambiguous name, name collision, or a REST error) is reported as a
        non-terminating error and does not stop the rest. NewName is not meaningful for a batch of more
        than one pool.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER StoragePoolName
        Current name of the storage pool to rename. Selects the pool in the ByName parameter set.
        Accepts pipeline input by property name (for example, from Get-DMstoragePool). Aliased to Name.

    .PARAMETER StoragePoolId
        ID of the storage pool to rename. Selects the pool in the ById parameter set. Use this when the
        pool ID is already known, or to avoid a name lookup. Accepts pipeline input by property name.
        Aliased to Id.

    .PARAMETER NewName
        New name to assign to the storage pool.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession, and storage pool objects by property
        name. A piped storage pool binds by its Name (the default parameter set); pass -StoragePoolId
        explicitly to select a pool by ID instead.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object indicating success or failure of the rename.

    .EXAMPLE
        PS> Rename-DMstoragePool -StoragePoolName 'Pool_01' -NewName 'Pool_01_archive' -WhatIf

    .EXAMPLE
        PS> Get-DMstoragePool -Name 'Pool_01' | Rename-DMstoragePool -NewName 'Pool_01_archive'

    .EXAMPLE
        PS> Rename-DMstoragePool -StoragePoolId '0' -NewName 'Pool_01_archive'
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$StoragePoolName,
        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')][ValidateNotNullOrEmpty()][string]$StoragePoolId,
        [Parameter(Mandatory, Position = 1)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $pools = @(Get-DMstoragePool -WebSession $session)

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $byId = @($pools | Where-Object { [string]$_.Id -eq [string]$StoragePoolId })
                if ($byId.Count -gt 1) {
                    throw "Storage pool ID '$StoragePoolId' is ambiguous."
                }
                if ($byId.Count -eq 0) {
                    throw "Invalid storage pool ID '$StoragePoolId'. Valid values are: $($pools.Id -join ', ')"
                }
                $currentName = $byId[0].Name
                $target = "ID $StoragePoolId"
            }
            else {
                $currentName = $StoragePoolName
                $target = $StoragePoolName
            }

            $update = New-DMNamedObjectUpdate -Objects $pools `
                -CurrentName $currentName -EntityName 'storage pool' -ResourceBase 'storagepool' `
                -NewName $NewName -NewNameSpecified

            if ($PSCmdlet.ShouldProcess($target, $update.Action)) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $update.Resource -BodyData $update.Body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
