function Remove-DMFiberChannelInitiatorFromHost {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) { $WebSession } else { $deviceManager }
                $hosts = @(get-DMhosts -WebSession $session)
                $matchingItems = @($hosts | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "HostName is ambiguous because more than one host is named '$candidate'." }
                throw "Invalid HostName. Valid values are: $($hosts.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
                (get-DMhosts -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) { $WebSession } else { $deviceManager }
                $selectedHostName = [string]$HostName
                $hostObject = @(get-DMhosts -WebSession $session | Where-Object Name -EQ $selectedHostName)[0]
                $initiators = @(get-DMHostInitiators -WebSession $session -InitatorType FibreChannel -HostId $hostObject.Id)
                if ($initiators.Id -contains $candidate) { return $true }
                throw "Invalid Fibre Channel initiator WWN for host '$selectedHostName'. Valid values are: $($initiators.Id -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('HostName')) { return }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
                (Get-DMFiberChannelInitiator -WebSession $session -HostName $fakeBoundParameters.HostName).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$WWN,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $body = @{ ID = $WWN }
    if ($VstoreId) { $body.vstoreId = $VstoreId }
    if ($PSCmdlet.ShouldProcess("$HostName/$WWN", 'Remove Fibre Channel initiator from host')) {
        return (invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'fc_initiator/remove_fc_from_host' -BodyData $body).error
    }
}
