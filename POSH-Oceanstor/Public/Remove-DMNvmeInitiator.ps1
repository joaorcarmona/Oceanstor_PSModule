function Remove-DMNvmeInitiator {
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
                $initiators = @(Get-DMNvmeInitiator -WebSession $session -FreeInitiators)
                if ($initiators.Id -contains $candidate) {
                    return $true
                }
                throw "Invalid free NVMe over RoCE initiator NQN. Valid values are: $($initiators.Id -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMNvmeInitiator -WebSession $session -FreeInitiators).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Nqn,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $body = @{ ID = $Nqn }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }
    if ($PSCmdlet.ShouldProcess($Nqn, 'Remove free NVMe over RoCE initiator')) {
        return (invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'NVMe_over_RoCE_initiator' -BodyData $body).error
    }
}
