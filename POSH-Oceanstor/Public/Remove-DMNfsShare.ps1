<#
.SYNOPSIS
    Removes an OceanStor NFS share.

.DESCRIPTION
    Deletes an existing NFS share by share path, optionally scoped to a vStore.
    The share path is validated against existing OceanStor NFS shares before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER SharePath
    Path of the NFS share to remove. The path is validated against existing OceanStor NFS shares.

.PARAMETER PrivateShare
    Sends sharePrivate=1 with the delete request for private NFS shares.

.PARAMETER VstoreId
    Optional vStore ID used to scope the NFS share removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMNfsShare -SharePath '/fs01/' -WhatIf

    Shows what would happen if the /fs01/ NFS share were removed.

.EXAMPLE
    PS> Remove-DMNfsShare -SharePath '/fs01/private/' -PrivateShare -Confirm

    Prompts for confirmation and sends the private share delete flag.

.NOTES
    Filename: Remove-DMNfsShare.ps1
#>
function Remove-DMNfsShare {
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
                    $deviceManager
                }
                $shares = @(Get-DMShares -WebSession $session -ShareType NFS)
                $matchingItems = @($shares | Where-Object 'Share Path' -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "SharePath is ambiguous because more than one NFS share uses '$_'."
                }
                throw "Invalid SharePath. Valid values are: $($shares.'Share Path' -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMShares -WebSession $session -ShareType NFS).'Share Path' |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SharePath,

        [switch]$PrivateShare,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $share = @(Get-DMShares -WebSession $session -ShareType NFS | Where-Object 'Share Path' -EQ $SharePath)[0]
    $parameters = @()
    if ($PrivateShare) {
        $parameters += 'sharePrivate=1'
    }
    if ($VstoreId) {
        $parameters += "vstoreId=$VstoreId"
    }
    $resource = "NFSSHARE/$($share.Id)"
    if ($parameters.Count -gt 0) {
        $resource += "?$($parameters -join '&')"
    }

    if ($PSCmdlet.ShouldProcess($SharePath, 'Remove NFS share')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
