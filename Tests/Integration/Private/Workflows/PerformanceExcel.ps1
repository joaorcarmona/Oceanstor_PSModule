# Phase 3 (Excel performance export) of the performance integrity validation. Read-only on
# the array; the only writes are local .xlsx files under $PerformanceOutputPath, which are
# registered as LocalFile cleanup entries and deleted at the end of the run.
#
# Export-DMStorageToExcel's -Hostname parameter set opens a NEW interactive connection, which
# a scripted run must never do; the -OceanStor parameter set is used instead with a synthetic
# view object built from the harness session (same property names the real OceanstorViewStorage
# exposes, capped to $MaxObjectsPerType objects per collection to keep the export light).

$script:PerformanceExcelWorkflow = {
    $excelCheckNames = @('Export-DMStorageToExcel:Performance', 'Export-DMStorageToExcel:FullExcludesPerformance')

    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Add-SkippedResult -Name $excelCheckNames -Status 'Blocked' -Category 'PerformanceRead' -Reason 'The ImportExcel module is not available on this machine.'
        return
    }

    $excelTraceStart = $performanceRequests.Count

    $script:performanceExcelView = $null
    Add-ValidationResult -Name 'Performance:BuildExcelStorageView' -Category 'PerformanceRead' -Action {
        $excelSystem = @(Get-DMSystem -WebSession $session)[0]
        if (-not $excelSystem) {
            throw 'Get-DMSystem returned nothing; cannot build the export view.'
        }
        $script:performanceExcelView = [pscustomobject]@{
            Session      = $session
            WebSession   = $session
            System       = $excelSystem
            Controllers  = @(Get-DMController -WebSession $session | Select-Object -First $MaxObjectsPerType)
            StoragePools = @(Get-DMstoragePool -WebSession $session | Select-Object -First $MaxObjectsPerType)
            disks        = @(Get-DMdisk -WebSession $session | Select-Object -First $MaxObjectsPerType)
            hosts        = @(Get-DMhost -WebSession $session | Select-Object -First $MaxObjectsPerType)
            luns         = @(Get-DMlun -WebSession $session | Select-Object -First $MaxObjectsPerType)
            LunGroups    = @(Get-DMlunGroup -WebSession $session | Select-Object -First $MaxObjectsPerType)
            hostgroups   = @(Get-DMhostGroup -WebSession $session | Select-Object -First $MaxObjectsPerType)
            vStores      = @(Get-DMvStore -WebSession $session | Select-Object -First $MaxObjectsPerType)
        }
        $script:performanceExcelView
    } | Out-Null

    if (-not $script:performanceExcelView) {
        Add-SkippedResult -Name $excelCheckNames -Status 'Blocked' -Category 'PerformanceRead' -Reason 'The synthetic export view could not be built (see Performance:BuildExcelStorageView).'
        return
    }

    # --- performance-only export --------------------------------------------------------------
    $perfExcelPath = Join-Path $PerformanceOutputPath "$(New-TestName -Suffix "p$($script:perfRunToken)_perf").xlsx"
    Register-PerformanceCleanup -Kind LocalFile -Id $perfExcelPath -Name 'performance-only Excel export' `
        -CleanupCommand "Remove-Item -LiteralPath '$perfExcelPath' -Force" | Out-Null

    Add-ValidationResult -Name 'Export-DMStorageToExcel:Performance' -Category 'PerformanceRead' -Action {
        Export-DMStorageToExcel -OceanStor $script:performanceExcelView -IncludeObject performance -ReportFile $perfExcelPath
        if (-not (Test-Path -LiteralPath $perfExcelPath)) {
            throw 'The performance export did not create the report file.'
        }
        $excelFile = Get-Item -LiteralPath $perfExcelPath
        if ($excelFile.Length -eq 0) {
            throw 'The performance export file is empty.'
        }
        $excelSheets = @(Get-ExcelSheetInfo -Path $perfExcelPath | ForEach-Object { $_.Name })
        Add-PerformanceArtifact -Name 'ExcelPerformanceSheets' -Value $excelSheets
        if (@($excelSheets | Where-Object { $_ -like '*Performance*' }).Count -eq 0) {
            throw "No performance worksheet found in the export. Sheets present: $($excelSheets -join ', ')."
        }
        [pscustomobject]@{ File = $perfExcelPath; Bytes = $excelFile.Length; Sheets = $excelSheets }
    } | Out-Null

    # --- 'full' export must NOT imply the performance section ---------------------------------
    # The full path dereferences these collections without null guards, so an empty collection
    # would fail the export for array-shape reasons rather than behavior reasons: skip instead.
    $fullRequiredCollections = @('Controllers', 'StoragePools', 'disks', 'hosts', 'luns', 'LunGroups', 'hostgroups', 'vStores')
    $emptyCollections = @($fullRequiredCollections | Where-Object { @($script:performanceExcelView.$_).Count -eq 0 })
    if ($emptyCollections.Count -gt 0) {
        Add-SkippedResult -Name 'Export-DMStorageToExcel:FullExcludesPerformance' -Status 'NoData' -Category 'PerformanceRead' `
            -Reason "The 'full' export dereferences collections that are empty on this array: $($emptyCollections -join ', ')."
    }
    else {
        $fullExcelPath = Join-Path $PerformanceOutputPath "$(New-TestName -Suffix "p$($script:perfRunToken)_full").xlsx"
        Register-PerformanceCleanup -Kind LocalFile -Id $fullExcelPath -Name 'full Excel export' `
            -CleanupCommand "Remove-Item -LiteralPath '$fullExcelPath' -Force" | Out-Null

        Add-ValidationResult -Name 'Export-DMStorageToExcel:FullExcludesPerformance' -Category 'PerformanceRead' -Action {
            Export-DMStorageToExcel -OceanStor $script:performanceExcelView -IncludeObject full -ReportFile $fullExcelPath
            if (-not (Test-Path -LiteralPath $fullExcelPath)) {
                throw "The 'full' export did not create the report file."
            }
            $fullSheets = @(Get-ExcelSheetInfo -Path $fullExcelPath | ForEach-Object { $_.Name })
            Add-PerformanceArtifact -Name 'ExcelFullSheets' -Value $fullSheets
            $performanceSheets = @($fullSheets | Where-Object { $_ -like '*Performance*' })
            if ($performanceSheets.Count -gt 0) {
                throw "The 'full' export unexpectedly contains performance worksheets ($($performanceSheets -join ', ')); performance must stay opt-in."
            }
            [pscustomobject]@{ File = $fullExcelPath; Sheets = $fullSheets }
        } | Out-Null
    }

    # --- closing audit: the Excel section issued no mutating REST calls -----------------------
    Add-ValidationResult -Name 'Performance:TraceAudit:Excel' -Category 'PerformanceRead' -Action {
        Assert-PerformanceTraceReadOnly -FromIndex $excelTraceStart
    } | Out-Null
}
