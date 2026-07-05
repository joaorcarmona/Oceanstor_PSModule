function Import-DMPerformanceReportCsv {
    <#
    .SYNOPSIS
        Extracts a report-task export zip file and returns the CSV rows inside it.

    .DESCRIPTION
        Generic zip -> CSV-rows helper with no indicator-map knowledge, so it is independently
        testable. Every *.csv file found in the archive is imported and its rows returned, each
        tagged with the source filename via a SourceFile note property -- the report zip's
        internal layout (single file vs. per-object-type files) has not been confirmed against a
        live array.

    .PARAMETER ZipPath
        Path to the downloaded report zip file.

    .INPUTS
        None

    .OUTPUTS
        pscustomobject

    .EXAMPLE
        PS> Import-DMPerformanceReportCsv -ZipPath 'C:\temp\report.zip'

    .NOTES
        Filename: Import-DMPerformanceReportCsv.ps1
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DMPerformanceReport_$([guid]::NewGuid().ToString('N'))"
    [void](New-Item -ItemType Directory -Path $tempDir -Force)

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $tempDir)

        $rows = [System.Collections.Generic.List[object]]::new()
        $csvFiles = Get-ChildItem -Path $tempDir -Filter '*.csv' -Recurse
        foreach ($csvFile in $csvFiles) {
            foreach ($row in Import-Csv -LiteralPath $csvFile.FullName) {
                Add-Member -InputObject $row -MemberType NoteProperty -Name SourceFile -Value $csvFile.Name -Force
                $rows.Add($row)
            }
        }

        return $rows.ToArray()
    }
    finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
