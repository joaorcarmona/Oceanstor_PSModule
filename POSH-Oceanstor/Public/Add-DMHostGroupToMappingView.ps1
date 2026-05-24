function Add-DMHostGroupToMappingView {
    <#
    .SYNOPSIS
        Associates a Huawei OceanStor host group with a mapping view.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            if (@(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $_).Count -eq 1) { return $true }
            throw "Invalid MappingViewName. Valid values are: $((Get-DMMappingView -WebSession $session).Name -join ', ')"
        })]
        [string]$MappingViewName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            if (@(get-DMhostGroups -WebSession $session | Where-Object Name -EQ $_).Count -eq 1) { return $true }
            throw "Invalid HostGroupName. Valid values are: $((get-DMhostGroups -WebSession $session).Name -join ', ')"
        })]
        [string]$HostGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $view = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $MappingViewName)[0]
    $group = @(get-DMhostGroups -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 14; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) { $body.vstoreId = $VstoreId }

    if ($PSCmdlet.ShouldProcess("$HostGroupName -> $MappingViewName", 'Associate host group with mapping view')) {
        return (invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/CREATE_ASSOCIATE' -BodyData $body).error
    }
}
