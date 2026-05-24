function Remove-DMHostGroup {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor host group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $deviceManager }
                $groups = @(get-DMhostGroups -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "HostGroupName is ambiguous because more than one host group is named '$_'." }
                throw "Invalid HostGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
                (get-DMhostGroups -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $group = @(get-DMhostGroups -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
    $resource = "hostgroup/$($group.Id)"
    if ($VstoreId) { $resource += "?vstoreId=$VstoreId" }

    if ($PSCmdlet.ShouldProcess($HostGroupName, 'Remove host group')) {
        $response = invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
