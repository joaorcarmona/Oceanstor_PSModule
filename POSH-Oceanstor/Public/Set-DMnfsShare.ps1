<#
.SYNOPSIS
    Modifies an OceanStor NFS share.

.DESCRIPTION
    Updates the description or character encoding of an existing NFS share via
    PUT NFSSHARE/{id}. At least one of Description, CharacterEncoding must be supplied.

    Accepts multiple shares from the pipeline by property name (matching the piped
    object's Share Path property). Each share is resolved and modified independently:
    a failure is reported as a non-terminating error and does not stop the rest from
    being processed.

.PARAMETER WebSession
    Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

.PARAMETER SharePath
    Path of the NFS share to modify. The path is validated against existing OceanStor NFS shares.

.PARAMETER Description
    New description for the NFS share. Up to 255 characters.

.PARAMETER CharacterEncoding
    New character encoding. Only UTF-8 is currently supported by this cmdlet.

.PARAMETER PrivateShare
    Sends sharePrivate=1 with the modify request for private NFS shares.

.PARAMETER VstoreId
    Optional vStore ID used to scope the modify operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Set-DMnfsShare -SharePath '/fs01/' -Description 'Finance archive' -Confirm:$false

.NOTES
    Filename: Set-DMnfsShare.ps1
#>
function Set-DMnfsShare {
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

        [ValidateLength(0, 255)]
        [string]$Description,

        [ValidateSet('UTF-8')]
        [string]$CharacterEncoding,

        [switch]$PrivateShare,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $hasChanges = $PSBoundParameters.ContainsKey('Description') -or $PSBoundParameters.ContainsKey('CharacterEncoding')
            if (-not $hasChanges) {
                throw 'Specify at least one of Description, CharacterEncoding.'
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

            $body = @{ ID = $share.Id }
            if ($PSBoundParameters.ContainsKey('Description')) {
                $body.DESCRIPTION = $Description
            }
            if ($PSBoundParameters.ContainsKey('CharacterEncoding')) {
                $body.CHARACTERENCODING = switch ($CharacterEncoding) { 'UTF-8' { 0 } }
            }

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

            if (-not $PSCmdlet.ShouldProcess($SharePath, 'Modify NFS share')) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $resource -BodyData $body
            $response = $response | Assert-DMApiSuccess
            return $response.error
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
