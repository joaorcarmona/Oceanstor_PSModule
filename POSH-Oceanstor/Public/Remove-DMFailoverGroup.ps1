function Remove-DMFailoverGroup {
    <#
    .SYNOPSIS
        Removes an OceanStor failover group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [ValidateSet(0, 1)]
        [int]$MsgReturnType
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
                MsgReturnType = 'MSGRETURNTYPE'
            }

            if ($PSCmdlet.ShouldProcess($Id, 'Remove failover group')) {
                $response = if ($body.Count -gt 0) {
                    Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "failovergroup/$([uri]::EscapeDataString($Id))" -BodyData $body
                }
                else {
                    Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "failovergroup/$([uri]::EscapeDataString($Id))"
                }
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}

Set-Alias -Name Delete-DMFailoverGroup -Value Remove-DMFailoverGroup
