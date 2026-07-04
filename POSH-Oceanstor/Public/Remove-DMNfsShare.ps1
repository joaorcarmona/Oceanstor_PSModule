<#
.SYNOPSIS
    Removes an OceanStor NFS share.

.DESCRIPTION
    Deletes an existing NFS share by share path, optionally scoped to a vStore.
    The share path is validated against existing OceanStor NFS shares before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple shares from the pipeline by property name (matching the piped object's Share Path
    property). Each share is resolved and removed independently: a failure (e.g. an invalid/ambiguous
    path, or a REST error) is reported as a non-terminating error and does not stop the remaining
    shares from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Share Path')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMShare -WebSession $session -ShareType NFS).'Share Path' |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SharePath,

        [switch]$PrivateShare,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $shares = @(Get-DMShare -WebSession $session -ShareType NFS)
            $matchingItems = @($shares | Where-Object 'Share Path' -EQ $SharePath)
            if ($matchingItems.Count -eq 0) {
                throw "Invalid SharePath. Valid values are: $($shares.'Share Path' -join ', ')"
            }
            if ($matchingItems.Count -gt 1) {
                throw "SharePath is ambiguous because more than one NFS share uses '$SharePath'."
            }
            $share = $matchingItems[0]

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
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
