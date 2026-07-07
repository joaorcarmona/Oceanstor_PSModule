function Get-DMRemoteLun {
    <#
    .SYNOPSIS
        Gets OceanStor remote LUNs visible through a remote device.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByRemoteDevice')]
    [OutputType('OceanstorRemoteLun')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByRemoteDevice', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteDeviceId,

        [Parameter(ParameterSetName = 'ByRemoteDevice')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByRemoteDevice')]
        [ValidateSet('ReplicationSecondaryLun', 'HyperMetroSecondaryLun', 'ReplicationStandbySecondaryLun')]
        [string]$RemoteServiceType = 'ReplicationSecondaryLun',

        [ValidateSet('ReplicationDevice', 'HeterogeneousDevice', 'UnknownDevice', 'CloudReplicationDevice')]
        [string]$ArrayType = 'ReplicationDevice'
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $rssTypeMap = @{
        ReplicationSecondaryLun = 13
        HyperMetroSecondaryLun = 26
        ReplicationStandbySecondaryLun = 37
    }
    $arrayTypeMap = @{
        ReplicationDevice = 1
        HeterogeneousDevice = 2
        UnknownDevice = 3
        CloudReplicationDevice = 4
    }

    $resource = "remote_lun?RSSTYPE=$($rssTypeMap[$RemoteServiceType])&DEVICEID=$([uri]::EscapeDataString($RemoteDeviceId))&ARRAYTYPE=$($arrayTypeMap[$ArrayType])"
    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    $remoteLuns = foreach ($lun in @($response)) {
        $remoteLun = [OceanstorRemoteLun]::new($lun, $session)
        if ($Id -and $remoteLun.Id -ne $Id) {
            continue
        }
        if ($Name -and $remoteLun.Name -notlike $Name) {
            continue
        }
        $remoteLun
    }

    return @($remoteLuns)
}
