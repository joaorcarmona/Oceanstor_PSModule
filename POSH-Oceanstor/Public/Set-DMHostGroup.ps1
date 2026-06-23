function Set-DMHostGroup {
    <#
    .SYNOPSIS
        Modifies an OceanStor host group.
    .DESCRIPTION
        Modifies a host group by name. NewName and Description are first-class properties; ApiProperties
        passes additional Huawei host-group API fields through unchanged.
    .EXAMPLE
        PS> Set-DMHostGroup -HostGroupName 'cluster' -NewName 'cluster-prod' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$HostGroupName,
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [AllowEmptyString()][ValidateLength(0, 255)][string]$Description,
        [System.Collections.IDictionary]$ApiProperties,
        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $update = New-DMNamedObjectUpdate -Objects @(Get-DMhostGroup -WebSession $session) `
        -CurrentName $HostGroupName -EntityName 'host group' -ResourceBase 'hostgroup' -NewName $NewName `
        -NewNameSpecified:$($PSBoundParameters.ContainsKey('NewName')) -Description $Description `
        -DescriptionSpecified:$($PSBoundParameters.ContainsKey('Description')) -ApiProperties $ApiProperties -VstoreId $VstoreId

    if ($PSCmdlet.ShouldProcess($HostGroupName, $update.Action)) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $update.Resource -BodyData $update.Body).error
    }
}
