function Remove-DMProtectionGroup {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor protection group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $groups = @(Get-DMProtectionGroup -WebSession $session)
            $matches = @($groups | Where-Object Name -EQ $_)
            if ($matches.Count -eq 1) { return $true }
            if ($matches.Count -gt 1) { throw "Name is ambiguous because more than one protection group is named '$_'." }
            throw "Invalid protection group Name. Valid values are: $($groups.Name -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (Get-DMProtectionGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$Name
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $group = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $Name)[0]

    if ($PSCmdlet.ShouldProcess($Name, 'Remove protection group')) {
        $response = invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "protectgroup/$($group.Id)" -ApiV2
        return $response.error
    }
}
