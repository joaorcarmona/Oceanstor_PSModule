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
            # The modify interface (PUT failovergroup/{id}, OceanStor Dorado 6.1.6 REST
            # reference 4.6.9.3.7) marks ID as a Mandatory body field; NAME/DESCRIPTION/
            # MSGRETURNTYPE are Optional. The doc's terse example body omits ID, but the
            # Parameters table is the contract: sending the changed fields alone (ID only
            # in the URL path) makes the array reject the payload with error 50331651. Id
            # is a Mandatory parameter, so it is always present to echo in the body.
            $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
                Id            = 'ID'
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
