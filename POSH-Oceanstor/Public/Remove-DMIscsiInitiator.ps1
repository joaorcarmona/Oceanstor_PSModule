function Remove-DMIscsiInitiator {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            $candidate = $_
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $initiators = @(Get-DMIscsiInitiator -WebSession $session -FreeInitiators)
            if ($initiators.Id -contains $candidate) { return $true }
            throw "Invalid free iSCSI initiator identifier. Valid values are: $($initiators.Id -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (Get-DMIscsiInitiator -WebSession $session -FreeInitiators).Id | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$Identifier,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $resource = "iscsi_initiator/$Identifier"
    if ($VstoreId) { $resource += "?vstoreId=$VstoreId" }
    if ($PSCmdlet.ShouldProcess($Identifier, 'Remove free iSCSI initiator')) {
        return (invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource).error
    }
}
