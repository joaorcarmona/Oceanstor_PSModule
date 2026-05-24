function Remove-DMHostFromHostGroup {
    <#
    .SYNOPSIS
        Removes a host association from a Huawei OceanStor host group.
    #>
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
                $groups = @(get-DMhostGroups -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "HostGroupName is ambiguous because more than one host group is named '$candidate'." }
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
    $hostObject = @(get-DMhosts -WebSession $session | Where-Object Name -EQ $HostName)[0]
    $group = @(get-DMhostGroups -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
    $members = @(get-DMhostsbyHostGroupId -WebSession $session -HostGroupId $group.Id)
    if ($members.Id -notcontains $hostObject.Id) {
        throw "Host '$HostName' is not a member of host group '$HostGroupName'."
    }

    $body = @{
        ID               = $group.Id
        ASSOCIATEOBJTYPE = 21
        ASSOCIATEOBJID   = $hostObject.Id
    }
    if ($VstoreId) { $body.vstoreId = $VstoreId }

    if ($PSCmdlet.ShouldProcess("$HostName <- $HostGroupName", 'Remove host from host group')) {
        return (invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'host/associate' -BodyData $body).error
    }
}
