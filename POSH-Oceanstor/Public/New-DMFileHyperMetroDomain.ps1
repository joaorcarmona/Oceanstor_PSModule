function New-DMFileHyperMetroDomain {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType('OceanstorFileHyperMetroDomain')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,30}$')][string]$Name,
        [ValidateLength(0, 127)][string]$Description,
        [Parameter(Mandatory = $true)][object[]]$RemoteDevices,
        [ValidateSet('ActiveActive', 'Synchronous', 'ActivePassive')][string]$WorkMode,
        [bool]$SynchronizeNetwork,
        [bool]$SynchronizeShareAuthentication,
        [hashtable]$ApiProperties
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{ NAME = $Name; REMOTEDEVICES = @($RemoteDevices) }
    Add-DMOptionalBodyValue -Body $body -Key 'DESCRIPTION' -Value $Description -IsPresent $PSBoundParameters.ContainsKey('Description')
    if ($WorkMode) {
        $body.workMode = switch ($WorkMode) {
            'ActiveActive' { '0' }
            'Synchronous' { '1' }
            'ActivePassive' { '2' }
        }
    }
    Add-DMOptionalBodyValue -Body $body -Key 'isNetworkSync' -Value $SynchronizeNetwork -IsPresent $PSBoundParameters.ContainsKey('SynchronizeNetwork')
    Add-DMOptionalBodyValue -Body $body -Key 'isShareAuthenticationSync' -Value $SynchronizeShareAuthentication -IsPresent $PSBoundParameters.ContainsKey('SynchronizeShareAuthentication')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }
    if ($PSCmdlet.ShouldProcess($Name, 'Create file-system HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'FsHyperMetroDomain' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorFileHyperMetroDomain]::new($response.data, $session)
        }
        return $response.error
    }
}
