function Get-DMTimeZone {
    <#
    .SYNOPSIS
        Gets the OceanStor equipment time zone.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'system_timezone' |
        Select-DMResponseData

    [pscustomobject]@{
        TimeZone         = $response.CMO_SYS_TIME_ZONE
        TimeZoneName     = $response.CMO_SYS_TIME_ZONE_NAME
        NameStyle        = $response.CMO_SYS_TIME_ZONE_NAME_STYLE
        UsesDaylightTime = $response.CMO_SYS_TIME_ZONE_USE_DST -eq '1'
    }
}
