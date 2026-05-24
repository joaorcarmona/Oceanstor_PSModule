function Add-DMLunGroupToMappingView {
    <#
    .SYNOPSIS
        Associates a Huawei OceanStor LUN group with a mapping view.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$MappingViewName,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$LunGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $view = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $MappingViewName)[0]
    if (-not $view) { throw "Mapping view '$MappingViewName' was not found." }
    $group = @(get-DMlunGroups -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    if (-not $group) { throw "LUN group '$LunGroupName' was not found." }
    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 256; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) { $body.vstoreId = $VstoreId }

    if ($PSCmdlet.ShouldProcess("$LunGroupName -> $MappingViewName", 'Associate LUN group with mapping view')) {
        return (invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/CREATE_ASSOCIATE' -BodyData $body).error
    }
}
