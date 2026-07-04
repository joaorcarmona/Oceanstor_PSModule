<#
.SYNOPSIS
    Modifies an OceanStor CIFS share.

.DESCRIPTION
    Updates the description or access-based enumeration setting of an existing CIFS
    share via PUT CIFSSHARE/{id}. At least one of Description, EnableAccessBasedEnum
    must be supplied.

    Accepts multiple shares from the pipeline by property name. Each share is resolved
    and modified independently: a failure is reported as a non-terminating error and
    does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

.PARAMETER ShareName
    Name of the CIFS share to modify. The name is validated against existing OceanStor CIFS shares.

.PARAMETER Description
    New description for the CIFS share. Up to 255 characters.

.PARAMETER EnableAccessBasedEnum
    Enables or disables access-based enumeration for the CIFS share.

.PARAMETER VstoreId
    Optional vStore ID used to scope the modify operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Set-DMCifsShare -ShareName 'share01' -Description 'Finance archive' -Confirm:$false

.NOTES
    Filename: Set-DMCifsShare.ps1
#>
function Set-DMCifsShare {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
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

        [ValidateLength(0, 255)]
        [string]$Description,

        [bool]$EnableAccessBasedEnum,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $hasChanges = $PSBoundParameters.ContainsKey('Description') -or $PSBoundParameters.ContainsKey('EnableAccessBasedEnum')
            if (-not $hasChanges) {
                throw 'Specify at least one of Description, EnableAccessBasedEnum.'
            }

            $shares = @(Get-DMShare -WebSession $session -ShareType CIFS)
            $matchingItems = @($shares | Where-Object Name -EQ $ShareName)
            if ($matchingItems.Count -eq 0) {
                throw "Invalid ShareName. Valid values are: $($shares.Name -join ', ')"
            }
            if ($matchingItems.Count -gt 1) {
                throw "ShareName is ambiguous because more than one CIFS share is named '$ShareName'."
            }
            $share = $matchingItems[0]

            $body = @{ ID = $share.Id }
            if ($PSBoundParameters.ContainsKey('Description')) {
                $body.DESCRIPTION = $Description
            }
            if ($PSBoundParameters.ContainsKey('EnableAccessBasedEnum')) {
                $body.ABEENABLE = $EnableAccessBasedEnum
            }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if (-not $PSCmdlet.ShouldProcess($ShareName, 'Modify CIFS share')) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "CIFSSHARE/$($share.Id)" -BodyData $body
            $response = $response | Assert-DMApiSuccess
            return $response.error
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
