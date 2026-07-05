function Get-DMRemoteDevice {
    <#
    .SYNOPSIS
        Gets OceanStor remote devices used by replication and HyperMetro.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([OceanstorRemoteDevice])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $encodedId = [uri]::EscapeDataString($Id)
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "remote_device/$encodedId" |
            Select-DMResponseData
        return [OceanstorRemoteDevice]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'remote_device'
    $devices = foreach ($device in @($response)) {
        $remoteDevice = [OceanstorRemoteDevice]::new($device, $session)
        if ($Name -and $remoteDevice.Name -notlike $Name) {
            continue
        }
        $remoteDevice
    }

    return @($devices)
}
