function Set-DMPortGroup {
    <#
    .SYNOPSIS
        Modifies an OceanStor port group.
    .DESCRIPTION
        Modifies a port group by name. NewName and Description are first-class properties; ApiProperties
        passes additional Huawei port-group API fields through unchanged.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER PortGroupName
        Existing port group name to modify.

    .PARAMETER NewName
        New name for the port group.

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
        PS> Set-DMPortGroup -PortGroupName 'front-end' -NewName 'front-end-prod' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$PortGroupName,
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [AllowEmptyString()][ValidateLength(0, 63)][string]$Description,
        [System.Collections.IDictionary]$ApiProperties,
        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $update = New-DMNamedObjectUpdate -Objects @(Get-DMPortGroup -WebSession $session -VstoreId $VstoreId) `
        -CurrentName $PortGroupName -EntityName 'port group' -ResourceBase 'portgroup' -NewName $NewName `
        -NewNameSpecified:$($PSBoundParameters.ContainsKey('NewName')) -Description $Description `
        -DescriptionSpecified:$($PSBoundParameters.ContainsKey('Description')) -ApiProperties $ApiProperties -VstoreId $VstoreId

    if ($PSCmdlet.ShouldProcess($PortGroupName, $update.Action)) {
        return ((Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $update.Resource -BodyData $update.Body) | Assert-DMApiSuccess).error
    }
}
