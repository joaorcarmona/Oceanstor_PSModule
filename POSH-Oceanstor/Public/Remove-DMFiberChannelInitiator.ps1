function Remove-DMFiberChannelInitiator {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $initiators = @(Get-DMFiberChannelInitiator -WebSession $session -FreeInitiators)
                if ($initiators.Id -contains $candidate) {
                    return $true
                }
                throw "Invalid free Fibre Channel initiator WWN. Valid values are: $($initiators.Id -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMFiberChannelInitiator -WebSession $session -FreeInitiators).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$WWN,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $resource = "fc_initiator/$WWN"
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }
    if ($PSCmdlet.ShouldProcess($WWN, 'Remove free Fibre Channel initiator')) {
        return (invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource).error
    }
}
