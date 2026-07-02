<#
.SYNOPSIS
    Removes an OceanStor CIFS share.

.DESCRIPTION
    Deletes an existing CIFS share by name, optionally scoped to a vStore.
    The share name is validated against existing OceanStor CIFS shares before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER ShareName
    Name of the CIFS share to remove. The name is validated against existing OceanStor CIFS shares.

.PARAMETER VstoreId
    Optional vStore ID used to scope the CIFS share removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMCifsShare -ShareName 'share01' -WhatIf

    Shows what would happen if share01 were removed.

.NOTES
    Filename: Remove-DMCifsShare.ps1
#>
function Remove-DMCifsShare {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $shares = @(Get-DMShare -WebSession $session -ShareType CIFS)
                $matchingItems = @($shares | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "ShareName is ambiguous because more than one CIFS share is named '$_'."
                }
                throw "Invalid ShareName. Valid values are: $($shares.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMShare -WebSession $session -ShareType CIFS).Name |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$ShareName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $share = @(Get-DMShare -WebSession $session -ShareType CIFS | Where-Object Name -EQ $ShareName)[0]
    if ($null -eq $share) { throw "Could not resolve 'share' — the object may have been removed since parameter validation." }
    $resource = "CIFSSHARE/$($share.Id)"
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }

    if ($PSCmdlet.ShouldProcess($ShareName, 'Remove CIFS share')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
