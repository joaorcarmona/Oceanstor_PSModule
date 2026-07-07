function Set-DMMappingView {
    <#
    .SYNOPSIS
        Modifies an OceanStor mapping view.
    .DESCRIPTION
        Modifies a mapping view by name. NewName and Description are first-class properties; ApiProperties
        passes additional Huawei mapping-view API fields through unchanged.

        Accepts multiple mapping views from the pipeline by property name. Each mapping view is modified
        independently: a failure (e.g. an invalid/ambiguous name, a name collision, or a REST error)
        is reported as a non-terminating error and does not stop the rest from being processed.
        NewName is not meaningful for a batch of more than one mapping view.

        The underlying REST call is PUT /mappingview/{id}. Only the NAME and DESCRIPTION labels are
        changed; the host-group, LUN-group, and port-group associations that define the access path are
        never touched by this command (use the Add-/Remove-DM*ToMappingView commands for that). Because a
        mapping view is an access-path object, this command is high-impact by default.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER MappingViewName
        Existing mapping view name to modify.

    .PARAMETER NewName
        New name for the mapping view.

    .PARAMETER Description
        New description. An empty string clears the description.

    .PARAMETER ApiProperties
        Additional Huawei API modification fields to send verbatim.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object indicating success or failure of the modification.

    .EXAMPLE
        PS> Set-DMMappingView -MappingViewName 'db-view' -Description 'Production database mapping' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$MappingViewName,
        [ValidateLength(1, 31)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [AllowEmptyString()][ValidateLength(0, 63)][string]$Description,
        [System.Collections.IDictionary]$ApiProperties,
        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $update = New-DMNamedObjectUpdate -Objects @(Get-DMMappingView -WebSession $session -VstoreId $VstoreId) `
                -CurrentName $MappingViewName -EntityName 'mapping view' -ResourceBase 'mappingview' -NewName $NewName `
                -NewNameSpecified:$($PSBoundParameters.ContainsKey('NewName')) -Description $Description `
                -DescriptionSpecified:$($PSBoundParameters.ContainsKey('Description')) -ApiProperties $ApiProperties -VstoreId $VstoreId

            if ($PSCmdlet.ShouldProcess($MappingViewName, $update.Action)) {
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
