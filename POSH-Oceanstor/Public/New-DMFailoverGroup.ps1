function New-DMFailoverGroup {
    <#
    .SYNOPSIS
        Creates an OceanStor failover group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [ValidateSet(3)]
        [int]$FailoverGroupType = 3,

        [AllowEmptyString()]
        [ValidateLength(0, 127)]
        [string]$Description,

        [ValidateSet(0, 1)]
        [int]$MsgReturnType,

        [ValidateSet(0, 3)]
        [int]$FailoverGroupServiceType,

        [ValidateSet(0)]
        [int]$FailoverGroupIpType
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
        Name                     = 'NAME'
        FailoverGroupType        = 'FAILOVERGROUPTYPE'
        Description              = 'DESCRIPTION'
        MsgReturnType            = 'MSGRETURNTYPE'
        FailoverGroupServiceType = 'failoverGroupServiceType'
        FailoverGroupIpType      = 'failoverGroupIpType'
    }
    $body.FAILOVERGROUPTYPE = $FailoverGroupType

    if ($PSCmdlet.ShouldProcess($Name, 'Create failover group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'failovergroup' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0 -and $response.data) {
            return [OceanStorFailoverGroup]::new($response.data, $session)
        }

        return $response.error
    }
}
