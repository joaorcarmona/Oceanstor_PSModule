function Get-DMSyslogNotification {
    <#
    .SYNOPSIS
        Gets OceanStor syslog notification settings.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [ValidateRange(1, 3600)]
        [int]$TimeoutSec = 30
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'syslog' -TimeoutSec $TimeoutSec |
        Select-DMResponseData
    return [OceanStorSyslogNotification]::new($response, $session)
}
