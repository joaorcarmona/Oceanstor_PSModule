<#
.SYNOPSIS
    Removes an OceanStor LUN.

.DESCRIPTION
    Deletes an existing LUN by name, optionally scoped to a vStore.
    By default the storage system delete behavior is used; specify ImmediateDelete to request non-delayed deletion. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER LunName
    Name of the LUN to remove. The name is validated against existing OceanStor LUNs.

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

.NOTES
    Filename: Remove-DMLun.ps1
#>
function Remove-DMLun {
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
                $luns = @(Get-DMluns -WebSession $session)
                $matchingItems = @($luns | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunName is ambiguous because more than one LUN is named '$_'."
                }
                throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMluns -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [switch]$ImmediateDelete,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $lun = @(Get-DMluns -WebSession $session | Where-Object Name -EQ $LunName)[0]
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

    if ($PSCmdlet.ShouldProcess($LunName, 'Remove LUN and its data')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
