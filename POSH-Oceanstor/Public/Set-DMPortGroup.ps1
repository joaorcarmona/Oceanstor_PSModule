function Set-DMPortGroup {
    <#
    .SYNOPSIS
        Modifies an OceanStor port group.
    .DESCRIPTION
        Modifies a port group by name. NewName and Description are first-class properties; ApiProperties
        passes additional Huawei port-group API fields through unchanged.
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

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $update = New-DMNamedObjectUpdate -Objects @(Get-DMPortGroup -WebSession $session -VstoreId $VstoreId) `
        -CurrentName $PortGroupName -EntityName 'port group' -ResourceBase 'portgroup' -NewName $NewName `
        -NewNameSpecified:$($PSBoundParameters.ContainsKey('NewName')) -Description $Description `
        -DescriptionSpecified:$($PSBoundParameters.ContainsKey('Description')) -ApiProperties $ApiProperties -VstoreId $VstoreId

    if ($PSCmdlet.ShouldProcess($PortGroupName, $update.Action)) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $update.Resource -BodyData $update.Body).error
    }
}
