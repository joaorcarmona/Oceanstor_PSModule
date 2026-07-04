<#
.SYNOPSIS
    Removes an OceanStor LUN.

.DESCRIPTION
    Deletes an existing LUN by name or ID, optionally scoped to a vStore.
    By default the storage system delete behavior is used; specify ImmediateDelete to request non-delayed deletion. The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple LUNs from the pipeline by property name (e.g. Get-DMlun output, matching its Name
    property). Each LUN is resolved and processed independently: a failure removing one LUN (e.g. an invalid
    or ambiguous name, a REST error, or the LUN being currently mapped) is reported as a non-terminating
    error and does not stop the remaining LUNs from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used. When a LUN object piped from Get-DMlun carries its own session, that session is used instead.

.PARAMETER LunName
    Name of the LUN to remove. Resolved against existing OceanStor LUNs (on the applicable session) when the command runs. Accepts pipeline input by property name (a piped object's Name property).

.PARAMETER LunId
    ID of the LUN to remove. This avoids name resolution and is the fastest path when the caller already has the LUN ID.

.PARAMETER ImmediateDelete
    Requests immediate deletion by sending isDelayDelete=false to the OceanStor API.

.PARAMETER VstoreId
    Optional vStore ID used to scope the LUN removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMLun -LunName 'lun01' -WhatIf

    Shows what would happen if lun01 were removed.

.EXAMPLE
    PS> Remove-DMLun -LunName 'lun01' -ImmediateDelete -Confirm

    Prompts for confirmation and requests immediate deletion of lun01.

.EXAMPLE
    PS> Get-DMlun | Where-Object Name -Like 'temp-*' | Remove-DMLun -Confirm:$false

    Removes every LUN whose name starts with temp-. A LUN that fails (e.g. because it is mapped) is
    reported as a non-terminating error; the rest are still processed.

.NOTES
    Filename: Remove-DMLun.ps1
#>
function Remove-DMLun {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', Position = 0, ValueFromPipelineByPropertyName = $true)]
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
                (Get-DMlun -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$LunName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]$LunId,

        [switch]$ImmediateDelete,

        [string]$VstoreId
    )

    process {
        $session = if ($WebSession) {
            $WebSession
        }
        else {
            $script:CurrentOceanstorSession
        }

        try {
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $matchingItems = @(Get-DMlun -WebSession $session -Id $LunId)
                if ($matchingItems.Count -eq 0) {
                    throw "Invalid LunId '$LunId'."
                }
            }
            else {
                $matchingItems = @(Get-DMlun -WebSession $session -Name $LunName | Where-Object Name -EQ $LunName)
                if ($matchingItems.Count -eq 0) {
                    throw "Invalid LunName '$LunName'."
                }
            }
            if ($matchingItems.Count -gt 1) {
                if ($PSCmdlet.ParameterSetName -eq 'ById') {
                    throw "LunId is ambiguous because more than one LUN has ID '$LunId'."
                }
                throw "LunName is ambiguous because more than one LUN is named '$LunName'."
            }
            $lun = $matchingItems[0]
            $targetName = if ($LunName) { $LunName } else { $lun.Name }

            if ($lun.'is Mapped' -eq 'mapped') {
                throw "Cannot remove LUN '$targetName': it is currently mapped to a host. Remove the mapping view first."
            }

            $parameters = @()
            if ($ImmediateDelete) {
                $parameters += 'isDelayDelete=false'
            }
            if ($VstoreId) {
                $parameters += "vstoreId=$VstoreId"
            }
            $resource = "lun/$($lun.Id)"
            if ($parameters.Count -gt 0) {
                $resource += "?$($parameters -join '&')"
            }

            if ($PSCmdlet.ShouldProcess($targetName, 'Remove LUN and its data')) {
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
