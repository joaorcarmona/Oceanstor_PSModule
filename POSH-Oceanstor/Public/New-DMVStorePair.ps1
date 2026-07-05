function New-DMVStorePair {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([OceanstorVStorePair])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$LocalVStoreId,
        [Parameter(Mandatory = $true)][string]$RemoteVStoreId,
        [Parameter(Mandatory = $true)][ValidateSet('HyperMetro', 'RemoteReplication')][string]$ReplicationType,
        [string]$RemoteDeviceId,
        [string]$DomainId,
        [ValidateSet('ConsistentWithActive', 'Manual')][string]$PreferredMode = 'ConsistentWithActive',
        [ValidateSet('Local', 'Remote')][string]$PreferredSite,
        [bool]$SynchronizeNetwork,
        [bool]$SynchronizeShareAuthentication,
        [hashtable]$ApiProperties
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($ReplicationType -eq 'RemoteReplication' -and -not $RemoteDeviceId) {
        throw 'RemoteDeviceId is required when ReplicationType is RemoteReplication.'
    }
    if ($ReplicationType -eq 'HyperMetro' -and -not $DomainId) {
        throw 'DomainId is required when ReplicationType is HyperMetro.'
    }

    $body = @{
        LOCALVSTOREID  = $LocalVStoreId
        REMOTEVSTOREID = $RemoteVStoreId
        REPTYPE        = if ($ReplicationType -eq 'HyperMetro') { '1' } else { '2' }
        PREFERREDMODE  = if ($PreferredMode -eq 'Manual') { '1' } else { '0' }
    }
    Add-DMOptionalBodyValue -Body $body -Key 'REMOTEDEVICEID' -Value $RemoteDeviceId -IsPresent $PSBoundParameters.ContainsKey('RemoteDeviceId')
    Add-DMOptionalBodyValue -Body $body -Key 'DOMAINID' -Value $DomainId -IsPresent $PSBoundParameters.ContainsKey('DomainId')
    if ($PreferredSite) { $body.PREFERREDSITE = if ($PreferredSite -eq 'Local') { '0' } else { '1' } }
    Add-DMOptionalBodyValue -Body $body -Key 'isNetworkSync' -Value $SynchronizeNetwork -IsPresent $PSBoundParameters.ContainsKey('SynchronizeNetwork')
    Add-DMOptionalBodyValue -Body $body -Key 'cmo_identity_preserve' -Value $SynchronizeShareAuthentication -IsPresent $PSBoundParameters.ContainsKey('SynchronizeShareAuthentication')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }

    if ($PSCmdlet.ShouldProcess("$LocalVStoreId -> $RemoteVStoreId", "Create $ReplicationType vStore pair")) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'vstore_pair' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorVStorePair]::new($response.data, $session)
        }
        return $response.error
    }
}
