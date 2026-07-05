function Set-DMFailoverGroup {
    <#
    .SYNOPSIS
        Modifies an OceanStor failover group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [AllowEmptyString()]
        [ValidateLength(0, 127)]
        [string]$Description,

        [ValidateSet(0, 1)]
        [int]$MsgReturnType
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
                Name          = 'NAME'
                Description   = 'DESCRIPTION'
                MsgReturnType = 'MSGRETURNTYPE'
            }

            if ($PSCmdlet.ShouldProcess($Id, 'Modify failover group')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "failovergroup/$([uri]::EscapeDataString($Id))" -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
