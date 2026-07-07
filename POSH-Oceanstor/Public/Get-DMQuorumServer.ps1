function Get-DMQuorumServer {
    <#
    .SYNOPSIS
        Gets OceanStor quorum servers used by HyperMetro domains.

    .DESCRIPTION
        Read-only inventory getter for quorum servers. Use it to resolve a
        QuorumServerId for Add-DMQuorumServerToHyperMetroDomain without opening
        the DeviceManager UI. Backed by the documented QuorumServer collection
        resource (OceanStor Dorado 6.1.6 REST Interface Reference, section
        4.9.8). Returns an empty array when no quorum servers are configured.

    .EXAMPLE
        Get-DMQuorumServer -WebSession $session

        Lists every quorum server known to the array.

    .EXAMPLE
        Get-DMQuorumServer -WebSession $session -Name 'quorum-a'

        Returns the quorum server whose name matches the -Name wildcard.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType('OceanStorQuorumServer')]
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
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QuorumServer/$encodedId" |
            Select-DMResponseData
        return [OceanStorQuorumServer]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'QuorumServer'
    $servers = foreach ($server in @($response)) {
        $quorumServer = [OceanStorQuorumServer]::new($server, $session)
        if ($Name -and $quorumServer.Name -notlike $Name) {
            continue
        }
        $quorumServer
    }

    return @($servers)
}
