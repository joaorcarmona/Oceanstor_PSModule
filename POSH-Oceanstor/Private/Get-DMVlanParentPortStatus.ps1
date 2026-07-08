function Get-DMVlanParentPortStatus {
    <#
    .SYNOPSIS
        Read-only idle-port guard for test-owned VLAN lifecycle workflows.

    .DESCRIPTION
        Determines whether a candidate parent port is idle enough to be used as
        the parent of a *test-owned* VLAN create/delete workflow. The guard is a
        pure read-only inspection built from the existing network inventory
        getters -- it never mutates, creates, or deletes any object.

        A port is treated as unsafe (InUse) when any existing association is
        found: a LIF homed on the port, a VLAN parented on the port, membership
        in a bond, or membership in a failover group. Any inspection failure is
        treated as Unknown (also unsafe): the guard never reports Idle unless it
        positively confirmed every checked association is empty.

        The caller must treat both InUse and Unknown as "do not use this port".

    .PARAMETER PortId
        ID of the candidate parent port to inspect.

    .PARAMETER WebSession
        Optional session for the REST reads. Defaults to the module's cached
        $script:CurrentOceanstorSession session.

    .OUTPUTS
        PSCustomObject with:
            PortId               - the inspected port ID
            IsIdle               - $true only when Status is 'Idle'
            Status               - 'Idle', 'InUse', or 'Unknown'
            Reasons              - human-readable reasons for InUse/Unknown
            CheckedAssociations  - association kinds that were inspected

    .NOTES
        Filename: Get-DMVlanParentPortStatus.ps1
        Read-only. Never mutates. Unknown state is unsafe by design.
    #>
    [CmdletBinding()]
    [OutputType('PSCustomObject')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$PortId,

        [Parameter()]
        [pscustomobject]$WebSession
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    $reasons = New-Object System.Collections.Generic.List[string]
    $errors = New-Object System.Collections.Generic.List[string]
    $checked = New-Object System.Collections.Generic.List[string]

    # 1. LIFs homed on the port (server-side HOMEPORTID filter).
    $checked.Add('Lif')
    try {
        $lifs = @(Get-DMLif -WebSession $session -HomePortId $PortId)
        if ($lifs.Count -gt 0) {
            $reasons.Add("Port hosts $($lifs.Count) LIF(s).")
        }
    }
    catch {
        $errors.Add("LIF association check failed: $($_.Exception.Message)")
    }

    # 2. VLANs parented on the port (VLAN 'Port Id' == candidate port).
    $checked.Add('Vlan')
    try {
        $childVlans = @(Get-DMvLan -WebSession $session | Where-Object { $_.'Port Id' -eq $PortId })
        if ($childVlans.Count -gt 0) {
            $reasons.Add("Port is the parent of $($childVlans.Count) VLAN(s).")
        }
    }
    catch {
        $errors.Add("VLAN association check failed: $($_.Exception.Message)")
    }

    # 3. Bond membership (port ID appears in a bond's Ethernet port list).
    $checked.Add('Bond')
    try {
        $memberBonds = @(Get-DMPortBond -WebSession $session |
                Where-Object { $_.'Ethernet Ports' -and ($_.'Ethernet Ports' -match [regex]::Escape($PortId)) })
        if ($memberBonds.Count -gt 0) {
            $reasons.Add("Port is a member of bond(s): $(($memberBonds.Name) -join ', ').")
        }
    }
    catch {
        $errors.Add("Bond membership check failed: $($_.Exception.Message)")
    }

    # 4. Failover-group membership (port ID appears among any group's members).
    $checked.Add('FailoverGroup')
    try {
        foreach ($group in @(Get-DMFailoverGroup -WebSession $session)) {
            $members = @(Get-DMFailoverGroupMember -WebSession $session -Id $group.Id)
            if ($members | Where-Object { $_.Id -eq $PortId }) {
                $reasons.Add("Port is a member of failover group '$($group.Name)'.")
            }
        }
    }
    catch {
        $errors.Add("Failover-group membership check failed: $($_.Exception.Message)")
    }

    # Precedence: a positively-found association is definitively unsafe (InUse).
    # If nothing was found but a check errored, we cannot confirm idle -> Unknown.
    # Only an all-clear, error-free inspection yields Idle.
    if ($reasons.Count -gt 0) {
        $status = 'InUse'
        $isIdle = $false
    }
    elseif ($errors.Count -gt 0) {
        $status = 'Unknown'
        $isIdle = $false
        foreach ($e in $errors) { $reasons.Add($e) }
    }
    else {
        $status = 'Idle'
        $isIdle = $true
    }

    return [pscustomobject]@{
        PortId              = $PortId
        IsIdle              = $isIdle
        Status              = $status
        Reasons             = $reasons.ToArray()
        CheckedAssociations = $checked.ToArray()
    }
}
