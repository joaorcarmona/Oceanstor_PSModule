function Get-DMutcTime {
    <#
    .SYNOPSIS
        Gets the OceanStor equipment UTC time.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'system_utc_time' |
        Select-DMResponseData

    $unixTime = [uint64]$response.CMO_SYS_UTC_TIME
    [pscustomobject]@{
        UtcTime     = $unixTime
        DateTimeUtc = [DateTimeOffset]::FromUnixTimeSeconds([int64]$unixTime).UtcDateTime
    }
}
