function Get-DMFileSystemReplicationPair {
    <#
    .SYNOPSIS
        Gets OceanStor remote replication pairs for a specific file system.

    .DESCRIPTION
        Read-only getter that returns the remote replication pair(s) whose local
        resource is the supplied file system. The narrowing is performed server-side
        via the documented REPLICATIONPAIR filter (OceanStor Dorado 6.1.6 REST
        Interface Reference, 4.9.2.4.1: LOCALRESID is an exact-match filter field),
        so the array returns only the matching pairs rather than the whole collection.
        The exact LOCALRESID match is re-verified client-side so an imprecise
        server-side result can never produce a wrong final answer.

    .PARAMETER FileSystemId
        Id of the local file system whose replication pairs should be returned. This
        is the file system's Id (LOCALRESID on the replication pair), not its name.

    .OUTPUTS
        OceanstorReplicationPair

    .EXAMPLE
        PS C:\> Get-DMFileSystemReplicationPair -FileSystemId 42

        Returns the replication pair(s) whose local file system Id is 42.
    #>
    [CmdletBinding()]
    [OutputType('OceanstorReplicationPair')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FileSystemId
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    # LOCALRESID is a documented exact-match filter field (double colon = exact).
    $resource = "REPLICATIONPAIR?filter=LOCALRESID::$([uri]::EscapeDataString($FileSystemId))"

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    $pairs = foreach ($pairData in @($response)) {
        $pair = [OceanstorReplicationPair]::new($pairData, $session)
        # Re-verify the exact local resource id even after the server-side filter.
        if ($pair.{Local Resource Id} -ne $FileSystemId) {
            continue
        }
        $pair
    }

    return @($pairs)
}
