function Remove-DMCifsShare {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor CIFS share.
    #>
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
                $shares = @(Get-DMShares -WebSession $session -ShareType CIFS)
                $matchingItems = @($shares | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "ShareName is ambiguous because more than one CIFS share is named '$_'."
                }
                throw "Invalid ShareName. Valid values are: $($shares.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMShares -WebSession $session -ShareType CIFS).Name |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$ShareName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $share = @(Get-DMShares -WebSession $session -ShareType CIFS | Where-Object Name -EQ $ShareName)[0]
    $resource = "CIFSSHARE/$($share.Id)"
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }

    if ($PSCmdlet.ShouldProcess($ShareName, 'Remove CIFS share')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
