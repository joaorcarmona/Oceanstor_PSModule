function Get-DMIscsiInitiator {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'Host')]
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

        [Parameter(ParameterSetName = 'Free')]
        [switch]$FreeInitiators
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    if ($HostName) {
        $hostObject = @(get-DMhosts -WebSession $session | Where-Object Name -EQ $HostName)[0]
        return @(get-DMHostInitiators -WebSession $session -InitatorType ISCSI -HostId $hostObject.Id)
    }
    if ($FreeInitiators) {
        return @(get-DMHostInitiators -WebSession $session -InitatorType ISCSI -FreeInitiators)
    }
    return @(get-DMHostInitiators -WebSession $session -InitatorType ISCSI -All)
}
