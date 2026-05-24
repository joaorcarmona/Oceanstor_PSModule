function Remove-DMPortGroup {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor port group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            $candidate = $_
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $groups = @(Get-DMPortGroup -WebSession $session)
            $matchingItems = @($groups | Where-Object Name -EQ $candidate)
            if ($matchingItems.Count -eq 1) { return $true }
            if ($matchingItems.Count -gt 1) { throw "PortGroupName is ambiguous because more than one port group is named '$candidate'." }
            throw "Invalid PortGroupName. Valid values are: $($groups.Name -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (Get-DMPortGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$PortGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $group = @(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $PortGroupName)[0]
    $resource = "portgroup/$($group.Id)"
    if ($VstoreId) { $resource += "?vstoreId=$VstoreId" }

    if ($PSCmdlet.ShouldProcess($PortGroupName, 'Remove port group')) {
        return (invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource).error
    }
}
