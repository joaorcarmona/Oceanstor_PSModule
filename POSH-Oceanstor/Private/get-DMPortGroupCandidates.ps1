function get-DMPortGroupCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true)]
        [ValidateSet('FibreChannel', 'Ethernet', 'LogicalPort')]
        [string]$PortType
    )

    switch ($PortType) {
        'FibreChannel' {
            @(get-DMPortFc -WebSession $WebSession) | ForEach-Object {
                [pscustomobject]@{ Id = $_.Id; Name = $_.Name; ObjectType = 212 }
            }
        }
        'Ethernet' {
            @(get-DMPortETH -WebSession $WebSession) | ForEach-Object {
                [pscustomobject]@{ Id = $_.Id; Name = $_.Name; ObjectType = 213 }
            }
        }
        'LogicalPort' {
            @(get-DMLifs -WebSession $WebSession) | ForEach-Object {
                [pscustomobject]@{ Id = $_.Id; Name = $_.'LIF Name'; ObjectType = 279 }
            }
        }
    }
}
