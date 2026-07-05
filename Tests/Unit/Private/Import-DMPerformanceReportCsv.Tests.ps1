BeforeDiscovery {
    $script:testModule = New-Module -Name ImportDMPerformanceReportCsvTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Import-DMPerformanceReportCsv.ps1"

        Export-ModuleMember -Function Import-DMPerformanceReportCsv
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name ImportDMPerformanceReportCsvTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope ImportDMPerformanceReportCsvTestModule {
    Describe 'Import-DMPerformanceReportCsv' {
        BeforeEach {
            $script:workDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            [void](New-Item -ItemType Directory -Path $script:workDir -Force)
        }

        function New-TestReportZip {
            param(
                [hashtable[]]$Files
            )

            $sourceDir = Join-Path $script:workDir 'source'
            [void](New-Item -ItemType Directory -Path $sourceDir -Force)

            foreach ($file in $Files) {
                Set-Content -LiteralPath (Join-Path $sourceDir $file.Name) -Value $file.Content
            }

            $zipPath = Join-Path $script:workDir 'report.zip'
            [System.IO.Compression.ZipFile]::CreateFromDirectory($sourceDir, $zipPath)
            return $zipPath
        }

        It 'returns rows from a single CSV file inside the zip' {
            $zip = New-TestReportZip -Files @(
                @{ Name = 'lun.csv'; Content = "object_id,timestamp,iops`n1,1700000000,123.4" }
            )

            $rows = Import-DMPerformanceReportCsv -ZipPath $zip

            $rows.Count | Should -Be 1
            $rows[0].object_id | Should -Be '1'
            $rows[0].iops | Should -Be '123.4'
        }

        It 'tags each row with the source filename' {
            $zip = New-TestReportZip -Files @(
                @{ Name = 'lun.csv'; Content = "object_id,iops`n1,10" }
            )

            $rows = Import-DMPerformanceReportCsv -ZipPath $zip

            $rows[0].SourceFile | Should -Be 'lun.csv'
        }

        It 'combines rows from multiple CSV files in the zip' {
            $zip = New-TestReportZip -Files @(
                @{ Name = 'lun.csv'; Content = "object_id,iops`n1,10" }
                @{ Name = 'controller.csv'; Content = "object_id,iops`nA,20" }
            )

            $rows = Import-DMPerformanceReportCsv -ZipPath $zip

            $rows.Count | Should -Be 2
            ($rows.SourceFile | Sort-Object) | Should -Be @('controller.csv', 'lun.csv')
        }

        It 'returns an empty array when the zip has no CSV files' {
            $zip = New-TestReportZip -Files @(
                @{ Name = 'readme.txt'; Content = 'not a csv' }
            )

            $rows = Import-DMPerformanceReportCsv -ZipPath $zip

            @($rows).Count | Should -Be 0
        }

        It 'cleans up its temporary extraction directory afterwards' {
            $zip = New-TestReportZip -Files @(
                @{ Name = 'lun.csv'; Content = "object_id,iops`n1,10" }
            )
            $tempRoot = [System.IO.Path]::GetTempPath()
            $before = @(Get-ChildItem -Path $tempRoot -Directory -Filter 'DMPerformanceReport_*' -ErrorAction SilentlyContinue)

            Import-DMPerformanceReportCsv -ZipPath $zip | Out-Null

            $after = @(Get-ChildItem -Path $tempRoot -Directory -Filter 'DMPerformanceReport_*' -ErrorAction SilentlyContinue)
            $after.Count | Should -Be $before.Count
        }
    }
}
