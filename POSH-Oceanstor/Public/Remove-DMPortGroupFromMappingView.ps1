function Remove-DMPortGroupFromMappingView {
    <#
    .SYNOPSIS
        Removes a port group association from a Huawei OceanStor mapping view.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$MappingViewName,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$PortGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $view = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $MappingViewName)[0]
    if (-not $view) { throw "Mapping view '$MappingViewName' was not found." }
    $group = @(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $PortGroupName)[0]
    if (-not $group) { throw "Port group '$PortGroupName' was not found." }
    $associations = @(Get-DMMappingView -WebSession $session -PortGroupName $PortGroupName -VstoreId $VstoreId)
    if ($associations.Id -notcontains $view.Id) {
        throw "Port group '$PortGroupName' is not associated with mapping view '$MappingViewName'."
    }

    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 257; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) { $body.vstoreId = $VstoreId }

    if ($PSCmdlet.ShouldProcess("$PortGroupName <- $MappingViewName", 'Remove port group from mapping view')) {
        return (invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/REMOVE_ASSOCIATE' -BodyData $body).error
    }
}
