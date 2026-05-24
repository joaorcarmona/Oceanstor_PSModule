function Remove-DMLunGroupFromMappingView {
    <#
    .SYNOPSIS
        Removes a LUN group association from a Huawei OceanStor mapping view.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$MappingViewName,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$LunGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $view = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $MappingViewName)[0]
    if (-not $view) {
        throw "Mapping view '$MappingViewName' was not found."
    }
    $group = @(get-DMlunGroups -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    if (-not $group) {
        throw "LUN group '$LunGroupName' was not found."
    }
    $associations = @(Get-DMMappingView -WebSession $session -LunGroupName $LunGroupName -VstoreId $VstoreId)
    if ($associations.Id -notcontains $view.Id) {
        throw "LUN group '$LunGroupName' is not associated with mapping view '$MappingViewName'."
    }

    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 256; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$LunGroupName <- $MappingViewName", 'Remove LUN group from mapping view')) {
        return (invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/REMOVE_ASSOCIATE' -BodyData $body).error
    }
}
