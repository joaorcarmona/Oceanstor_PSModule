function Add-DMPortGroupToMappingView {
    <#
    .SYNOPSIS
        Associates a Huawei OceanStor port group with a mapping view.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$MappingViewName,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$PortGroupName,

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
    $group = @(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $PortGroupName)[0]
    if (-not $group) {
        throw "Port group '$PortGroupName' was not found."
    }
    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 257; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$PortGroupName -> $MappingViewName", 'Associate port group with mapping view')) {
        return (invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/CREATE_ASSOCIATE' -BodyData $body).error
    }
}
