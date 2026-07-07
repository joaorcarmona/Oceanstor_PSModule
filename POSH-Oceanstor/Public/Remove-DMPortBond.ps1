function Remove-DMPortBond {
    <#
    .SYNOPSIS
        Removes an OceanStor bond port.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true)]
        [ValidateLength(1, 31)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [ValidateSet(0, 1)]
        [int]$MsgReturnType
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
                Name          = 'NAME'
                MsgReturnType = 'MSGRETURNTYPE'
            }
            $resource = if ($Id) { "bond_port/$([uri]::EscapeDataString($Id))" } else { 'bond_port' }
            $target = if ($Id) { $Id } else { $Name }
            if ($PSCmdlet.ShouldProcess($target, 'Remove bond port')) {
                $response = if ($body.Count -gt 0) {
                    Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource -BodyData $body
                }
                else {
                    Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
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

Set-Alias -Name Delete-DMPortBond -Value Remove-DMPortBond
