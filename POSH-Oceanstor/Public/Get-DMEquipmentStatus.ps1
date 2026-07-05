function Get-DMEquipmentStatus {
    <#
    .SYNOPSIS
        Gets the OceanStor equipment status.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'server/status' |
        Select-DMResponseData

    $status = [int]$response.status
    $statusName = switch ($status) {
        0 { 'Normal' }
        1 { 'Abnormal' }
        2 { 'PoweringOn' }
        3 { 'PoweringOff' }
        4 { 'SecurityMode' }
        5 { 'Upgrading' }
        6 { 'PowerSupplyFailing' }
        7 { 'Offline' }
        default { $response.status }
    }

    [pscustomobject]@{
        Status      = $status
        StatusName  = $statusName
        Description = $response.description
    }
}
