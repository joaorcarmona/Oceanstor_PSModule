function Get-DMSyslogNotification {
    <#
    .SYNOPSIS
        Gets OceanStor syslog notification settings.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'syslog' |
        Select-DMResponseData
    return [OceanStorSyslogNotification]::new($response, $session)
}
