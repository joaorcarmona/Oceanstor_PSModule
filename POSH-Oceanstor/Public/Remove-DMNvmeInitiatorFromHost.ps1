function Remove-DMNvmeInitiatorFromHost {
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
                $hosts = @(Get-DMhosts -WebSession $session)
                $matchingItems = @($hosts | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$candidate'."
                }
                throw "Invalid HostName. Valid values are: $($hosts.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMhosts -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $selectedHostName = [string]$HostName
                $hostObject = @(Get-DMhosts -WebSession $session | Where-Object Name -EQ $selectedHostName)[0]
                $resource = "NVMe_over_RoCE_initiator/associate?ASSOCIATEOBJTYPE=21&ASSOCIATEOBJID=$($hostObject.Id)"
                $initiators = @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource).data)
                if ($initiators.ID -contains $candidate) {
                    return $true
                }
                throw "Invalid NVMe over RoCE initiator NQN for host '$selectedHostName'. Valid values are: $($initiators.ID -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('HostName')) {
                    return
                }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMNvmeInitiator -WebSession $session -HostName $fakeBoundParameters.HostName).Id | Where-Object { $_ -like "$wordToComplete*" }
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
    $hostObject = @(Get-DMhosts -WebSession $session | Where-Object Name -EQ $HostName)[0]
    $body = @{
        ID               = $hostObject.Id
        ASSOCIATEOBJTYPE = 57870
        ASSOCIATEOBJID   = $Nqn
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }
    if ($PSCmdlet.ShouldProcess("$HostName/$Nqn", 'Remove NVMe over RoCE initiator from host')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'host/remove_associate' -BodyData $body).error
    }
}
