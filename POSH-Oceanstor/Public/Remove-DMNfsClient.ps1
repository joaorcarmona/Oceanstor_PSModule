function Remove-DMNfsClient {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor NFS share client.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $deviceManager }
                $clients = @(get-DMnfsFileClient -WebSession $session)
                $matchingItems = @($clients | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "ClientName is ambiguous because more than one NFS client is named '$_'." }
                throw "Invalid ClientName. Valid values are: $($clients.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
                (get-DMnfsFileClient -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$ClientName,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $client = @(get-DMnfsFileClient -WebSession $session | Where-Object Name -EQ $ClientName)[0]
    $resource = "NFS_SHARE_AUTH_CLIENT/$($client.Id)"
    if ($VstoreId) { $resource += "?vstoreId=$VstoreId" }

    if ($PSCmdlet.ShouldProcess($ClientName, 'Remove NFS share client')) {
        $response = invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
