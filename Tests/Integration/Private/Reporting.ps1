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
    $report | Format-List Hostname, RunAt, DurationMs, Mode, RunId, Passed, NoData, Skipped, Blocked, Failed, MutationLogPath, TracedMutationRequests, ExcludedCommands, RemainingTestOwnedResources
    $checks | Format-Table Category, Name, Status, DurationMs, Count, ExpectedType, ActualTypes, Error -AutoSize
}
