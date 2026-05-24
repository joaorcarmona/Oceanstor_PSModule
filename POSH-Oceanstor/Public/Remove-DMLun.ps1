function Remove-DMLun {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor LUN.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $deviceManager }
                $luns = @(get-DMluns -WebSession $session)
                $matchingItems = @($luns | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "LunName is ambiguous because more than one LUN is named '$_'." }
                throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
                (get-DMluns -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [switch]$ImmediateDelete,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $lun = @(get-DMluns -WebSession $session | Where-Object Name -EQ $LunName)[0]
    $parameters = @()
    if ($ImmediateDelete) { $parameters += 'isDelayDelete=false' }
    if ($VstoreId) { $parameters += "vstoreId=$VstoreId" }
    $resource = "lun/$($lun.Id)"
    if ($parameters.Count -gt 0) { $resource += "?$($parameters -join '&')" }

    if ($PSCmdlet.ShouldProcess($LunName, 'Remove LUN and its data')) {
        $response = invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
