function Set-DMHostInitiator {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$InputObject,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$WebSession
    )

    $hosts = @($InputObject)
    if ($hosts.Count -eq 0) {
        return
    }

    $initiatorsByHostId = @{}
    $allInitiators = @(
        Get-DMHostInitiator -WebSession $WebSession -InitiatorType FibreChannel -All
        Get-DMHostInitiator -WebSession $WebSession -InitiatorType ISCSI -All
    )

    foreach ($initiator in $allInitiators) {
        $hostId = [string]$initiator.'Host Id'
        if ([string]::IsNullOrWhiteSpace($hostId)) {
            continue
        }

        if (-not $initiatorsByHostId.ContainsKey($hostId)) {
            $initiatorsByHostId[$hostId] = [System.Collections.Generic.List[object]]::new()
        }

        $initiatorsByHostId[$hostId].Add($initiator)
    }

    foreach ($hostObject in $hosts) {
        $hostId = [string]$hostObject.id
        $hostObject.initiators = if ($initiatorsByHostId.ContainsKey($hostId)) {
            @($initiatorsByHostId[$hostId])
        }
        else {
            @()
        }

        $hostObject
    }
}
