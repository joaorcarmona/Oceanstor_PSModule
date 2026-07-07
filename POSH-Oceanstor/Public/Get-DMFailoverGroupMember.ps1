function Get-DMFailoverGroupMember {
    <#
    .SYNOPSIS
        Gets the port members of an OceanStor failover group.

    .DESCRIPTION
        Read-only getter that lists the members (Ethernet ports, bond ports and
        VLANs) associated with a failover group. The Dorado 6.1.6 REST reference
        does not document a GET on failovergroup/associate, so this command uses
        the documented per-type association queries instead:
        eth_port/associate, bond_port/associate and vlan/associate, each with
        ASSOCIATEOBJTYPE=289 (failover group) and the group ID.

    .PARAMETER WebSession
        Optional session for the REST calls. Defaults to the module's cached
        $script:CurrentOceanstorSession session.

    .PARAMETER Id
        ID of the failover group whose members are returned. Accepts pipeline
        input by property name, e.g. from Get-DMFailoverGroup.

    .PARAMETER MemberType
        Optional member type filter: 213 (Ethernet port), 235 (bond port),
        280 (VLAN). Defaults to all three.

    .INPUTS
        OceanStorFailoverGroup

        You can pipe failover group objects (property Id) to this command.

    .OUTPUTS
        OceanStorFailoverGroupMember

        Returns one object per failover group member; an empty result when the
        group has no members.

    .EXAMPLE
        PS C:\> Get-DMFailoverGroupMember -Id 0

    .EXAMPLE
        PS C:\> Get-DMFailoverGroup -Name fg01 | Get-DMFailoverGroupMember

    .NOTES
        Filename: Get-DMFailoverGroupMember.ps1

    .LINK
    #>
    [CmdletBinding()]
    [OutputType('OceanStorFailoverGroupMember')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [ValidateSet(213, 235, 280)]
        [int[]]$MemberType = @(213, 235, 280)
    )

    process {
        $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

        $defaultDisplaySet = 'Id', 'Name', 'Member Type', 'Running Status', 'Failover Group Id'
        $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
            'DefaultDisplayPropertySet',
            [string[]]$defaultDisplaySet
        )
        $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

        # Documented association queries per member type (REST reference
        # 4.6.9.4.10 bond, 4.6.9.4.11 eth, and the VLAN associated query).
        $memberEndpoints = @{
            213 = 'eth_port/associate'
            235 = 'bond_port/associate'
            280 = 'vlan/associate'
        }

        $members = New-Object System.Collections.ArrayList
        foreach ($type in @($MemberType | Sort-Object -Unique)) {
            $resource = "$($memberEndpoints[$type])?ASSOCIATEOBJTYPE=289&ASSOCIATEOBJID=$([uri]::EscapeDataString($Id))"
            $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource | Select-DMResponseData
            foreach ($tmember in @($response)) {
                if ($null -eq $tmember) { continue }
                $member = [OceanStorFailoverGroupMember]::new($tmember, $Id, $session)
                [void]$members.Add($member)
            }
        }

        $members | ForEach-Object {
            $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        }

        return $members
    }
}

Set-Alias -Name Get-DMFailoverGroupMembers -Value Get-DMFailoverGroupMember
