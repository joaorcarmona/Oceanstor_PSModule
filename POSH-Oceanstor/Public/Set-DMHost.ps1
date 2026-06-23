function Set-DMHost {
    <#
    .SYNOPSIS
        Modifies an OceanStor host.
    .DESCRIPTION
        Modifies a host by name. NewName and Description are first-class properties; ApiProperties passes
        additional Huawei host API fields through unchanged. ID and NAME are reserved ApiProperties keys.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The global deviceManager session is used by default.

    .PARAMETER HostName
        Existing host name to modify.

    .PARAMETER NewName
        New name for the host.

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
        PS> Set-DMHost -HostName 'esx01' -NewName 'esx01-prod' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$HostName,
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [AllowEmptyString()][ValidateLength(0, 255)][string]$Description,
        [System.Collections.IDictionary]$ApiProperties,
        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $update = New-DMNamedObjectUpdate -Objects @(Get-DMhost -WebSession $session) `
        -CurrentName $HostName -EntityName 'host' -ResourceBase 'host' -NewName $NewName `
        -NewNameSpecified:$($PSBoundParameters.ContainsKey('NewName')) -Description $Description `
        -DescriptionSpecified:$($PSBoundParameters.ContainsKey('Description')) -ApiProperties $ApiProperties -VstoreId $VstoreId

    if ($PSCmdlet.ShouldProcess($HostName, $update.Action)) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $update.Resource -BodyData $update.Body).error
    }
}
