function Format-ValidationDuration {
    param([double]$Milliseconds)

    if ($Milliseconds -ge 1000) {
        return "{0:N2} s" -f ($Milliseconds / 1000)
    }
    return "{0:N0} ms" -f $Milliseconds
}

function ConvertTo-MarkdownTableCell {
    param([string]$Value)

    if ([string]::IsNullOrEmpty($Value)) {
        return ''
    }
    ($Value -replace '\|', '\|') -replace '\r?\n', ' '
}

function Write-ValidationMarkdownReport {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $runAtLocal = ([datetime]$Report.RunAt).ToLocalTime()

    $lines.Add('# OceanStor Integration Validation Report')
    $lines.Add('')
    $lines.Add("- **Hostname:** $($Report.Hostname)")
    $lines.Add("- **Run at:** $($runAtLocal.ToString('yyyy-MM-dd HH:mm:ss')) (local)")
    $lines.Add("- **Duration:** $(Format-ValidationDuration $Report.DurationMs)")
    $lines.Add("- **Mode:** $($Report.Mode)")
    $lines.Add("- **Run ID:** $($Report.RunId)")
    $lines.Add('')
    $lines.Add('## Summary')
    $lines.Add('')
    $lines.Add('| Passed | NoData | Skipped | Blocked | Failed |')
    $lines.Add('|---|---|---|---|---|')
    $lines.Add("| $($Report.Passed) | $($Report.NoData) | $($Report.Skipped) | $($Report.Blocked) | $($Report.Failed) |")
    $lines.Add('')

    $failedChecks = @($Report.Checks | Where-Object Status -in @('Failed', 'UnexpectedType'))
    if ($failedChecks.Count -gt 0) {
        $lines.Add('## Failures')
        $lines.Add('')
        $lines.Add('| Category | Check | Status | Error |')
        $lines.Add('|---|---|---|---|')
        foreach ($check in $failedChecks) {
            $lines.Add("| $($check.Category) | $($check.Name) | $($check.Status) | $(ConvertTo-MarkdownTableCell $check.Error) |")
        }
        $lines.Add('')
    }

    if ($Report.RemainingTestOwnedResources.Count -gt 0) {
        $lines.Add('## Remaining Test-Owned Resources')
        $lines.Add('')
        $lines.Add('These resources were created by this run and were not cleaned up:')
        $lines.Add('')
        foreach ($resource in $Report.RemainingTestOwnedResources) {
            $lines.Add("- $resource")
        }
        $lines.Add('')
    }

    if ($Report.ExcludedCommands.Count -gt 0) {
        $lines.Add('## Excluded Commands')
        $lines.Add('')
        $lines.Add(($Report.ExcludedCommands -join ', '))
        $lines.Add('')
    }

    $slowChecks = @(
        $Report.Checks |
            Where-Object { $null -ne $_.DurationMs } |
            Sort-Object DurationMs -Descending |
            Select-Object -First 10
    )
    if ($slowChecks.Count -gt 0) {
        $lines.Add('## Slowest Checks')
        $lines.Add('')
        $lines.Add('| Category | Check | Duration | Status | Count |')
        $lines.Add('|---|---|---|---|---|')
        foreach ($check in $slowChecks) {
            $lines.Add("| $($check.Category) | $($check.Name) | $(Format-ValidationDuration $check.DurationMs) | $($check.Status) | $($check.Count) |")
        }
        $lines.Add('')
    }

    $lines.Add('## Checks')
    $lines.Add('')

    $categoryOrder = @('Session', 'Read', 'Mutation', 'MutationRead')
    $groupedChecks = @($Report.Checks | Group-Object Category)
    $orderedGroups = @(
        foreach ($category in $categoryOrder) {
            $groupedChecks | Where-Object Name -eq $category
        }
        $groupedChecks | Where-Object { $categoryOrder -notcontains $_.Name }
    )

    foreach ($group in $orderedGroups) {
        $lines.Add("### $($group.Name)")
        $lines.Add('')
        $lines.Add('| Check | Status | Duration | Count | Type | Error |')
        $lines.Add('|---|---|---|---|---|---|')
        foreach ($check in $group.Group) {
            $type = if ($check.ActualTypes) { $check.ActualTypes -join ', ' } else { '' }
            $lines.Add("| $($check.Name) | $($check.Status) | $(Format-ValidationDuration $check.DurationMs) | $($check.Count) | $(ConvertTo-MarkdownTableCell $type) | $(ConvertTo-MarkdownTableCell $check.Error) |")
        }
        $lines.Add('')
    }

    $lines | Set-Content -LiteralPath $Path
}

function Write-ValidationReport {
    $representedCommands = @(
        $checks.Name |
            ForEach-Object { ($_ -replace '^Verify:', '' -split ':')[0] } |
            Sort-Object -Unique
    )
    $unrepresentedCommands = @(
        Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Public') -Filter '*.ps1' |
            Select-Object -ExpandProperty BaseName |
            Where-Object { $representedCommands -notcontains $_ -and $excludedCommands -notcontains $_ }
    )
    if ($unrepresentedCommands.Count -gt 0) {
        $unrepresentedStatus = if ($RunMutatingTests -and $configuration.AllowMutatingTests) { 'Blocked' } else { 'NotExecuted' }
        $unrepresentedReason = if ($unrepresentedStatus -eq 'Blocked') {
            'This command could not run because its test-owned prerequisite resource was not created successfully during this run.'
        }
        else {
            'This command did not have the prerequisite live data or an enabled safe lifecycle during this run.'
        }
        Add-SkippedResult -Name $unrepresentedCommands -Status $unrepresentedStatus -Reason $unrepresentedReason
    }

    $remainingOwned = @(
        foreach ($kind in $owned.Keys) {
            foreach ($identity in $owned[$kind]) {
                "${kind}:$identity"
            }
        }
    )

    $report = [pscustomobject]@{
        Hostname    = $Hostname
        RunAt       = (Get-Date).ToString('o')
        DurationMs  = [math]::Round(((Get-Date) - $runStartedAt).TotalMilliseconds, 2)
        Mode        = if ($RunMutatingTests) { 'GET validation and opt-in test-owned mutation workflows' } else { 'Read-only GET validation; mutation workflows not requested' }
        RunId       = $runId
        Passed      = @($checks | Where-Object Status -eq 'Passed').Count
        NoData      = @($checks | Where-Object Status -eq 'NoData').Count
        Skipped     = @($checks | Where-Object Status -in @('SkippedUnsafe', 'NotConfigured', 'NotRequested', 'NotExecuted', 'Blocked')).Count
        Blocked     = @($checks | Where-Object Status -eq 'Blocked').Count
        Failed      = @($checks | Where-Object Status -in @('Failed', 'UnexpectedType')).Count
        MutationLogPath = if ($RunMutatingTests -and $configuration.AllowMutatingTests) { $MutationLogPath } else { $null }
        TracedMutationRequests = $mutationRequests.Count
        ExcludedCommands = $excludedCommands
        RemainingTestOwnedResources = $remainingOwned
        Checks      = $checks
    }

    if ($RunMutatingTests -and $configuration.AllowMutatingTests) {
        $mutationLog = [pscustomobject]@{
            Hostname    = $Hostname
            RunAt       = (Get-Date).ToString('o')
            RunId       = $runId
            ReportPath  = $ReportPath
            RequestCount = $mutationRequests.Count
            FailedChecks = @($checks | Where-Object { $_.Category -in @('Mutation', 'MutationRead') -and $_.Status -in @('Failed', 'UnexpectedType') })
            RemainingTestOwnedResources = $remainingOwned
            Requests    = $mutationRequests
        }
        $mutationLog | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $MutationLogPath
    }

    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath
    Write-ValidationMarkdownReport -Report $report -Path $MarkdownReportPath
    $report | Format-List Hostname, RunAt, DurationMs, Mode, RunId, Passed, NoData, Skipped, Blocked, Failed, MutationLogPath, TracedMutationRequests, ExcludedCommands, RemainingTestOwnedResources
    $checks | Format-Table Category, Name, Status, DurationMs, Count, ExpectedType, ActualTypes, Error -AutoSize
}
