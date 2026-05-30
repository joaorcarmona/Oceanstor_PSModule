function Remove-DMNfsShare {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor NFS share.
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
                $shares = @(Get-DMShares -WebSession $session -ShareType NFS)
                $matchingItems = @($shares | Where-Object 'Share Path' -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "SharePath is ambiguous because more than one NFS share uses '$_'."
                }
                throw "Invalid SharePath. Valid values are: $($shares.'Share Path' -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMShares -WebSession $session -ShareType NFS).'Share Path' |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SharePath,

        [switch]$PrivateShare,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $share = @(Get-DMShares -WebSession $session -ShareType NFS | Where-Object 'Share Path' -EQ $SharePath)[0]
    $parameters = @()
    if ($PrivateShare) {
        $parameters += 'sharePrivate=1'
    }
    if ($VstoreId) {
        $parameters += "vstoreId=$VstoreId"
    }
    $resource = "NFSSHARE/$($share.Id)"
    if ($parameters.Count -gt 0) {
        $resource += "?$($parameters -join '&')"
    }

    if ($PSCmdlet.ShouldProcess($SharePath, 'Remove NFS share')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
