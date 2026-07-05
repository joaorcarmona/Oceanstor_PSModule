function Remove-DMLif {
    <#
    .SYNOPSIS
        Removes an OceanStor logical interface port.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('LIF Name')]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$Id,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
                Name     = 'NAME'
                Id       = 'id'
                VstoreId = 'vstoreId'
            }

            if ($PSCmdlet.ShouldProcess($Name, 'Remove logical interface')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'lif' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}

Set-Alias -Name Delete-DMLif -Value Remove-DMLif
