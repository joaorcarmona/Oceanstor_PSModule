[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Hostname,

    [pscredential]$Credential,

    [switch]$SkipCertificateCheck,

    [string]$ReportPath = (Join-Path $PSScriptRoot '..\..\Reports\getter-integrity-last-result.json'),

    [string]$MarkdownReportPath = (Join-Path $PSScriptRoot '..\..\Reports\getter-integrity-last-result.md'),

    [string]$RunLogPath = (Join-Path $PSScriptRoot '..\..\Reports\getter-integrity-run.log'),

    [string]$MutationLogPath = (Join-Path $PSScriptRoot '..\..\Reports\mutation-trace-last-result.json'),

    [string]$ConfigurationPath = (Join-Path $PSScriptRoot 'IntegrityValidationConfig.psd1'),

    [switch]$RunMutatingTests,

    [switch]$RunPipelineBatchCoverage,

    [switch]$IncludePerformance,

    [switch]$IncludePerformanceHistory,

    [switch]$IncludeCapacityHistory,

    [switch]$IncludeExcelPerformance,

    [switch]$AllowMonitoringMutation,

    [switch]$KeepCreatedReportTasks,

    [ValidateRange(1, 100)]
    [int]$MaxObjectsPerType = 2,

    [ValidateRange(1, 86400)]
    [int]$PerformanceTimeoutSec = 300,

    [string]$PerformanceOutputPath,

    [switch]$NoProgress,

    [switch]$ShowTestExecution
)

$ErrorActionPreference = 'Stop'
$runStartedAt = Get-Date

foreach ($outputPath in @($ReportPath, $MarkdownReportPath, $RunLogPath, $MutationLogPath)) {
    $outputDirectory = Split-Path -Path $outputPath -Parent
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
        $null = New-Item -Path $outputDirectory -ItemType Directory -Force
    }
}

$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
if ($RunPipelineBatchCoverage) {
    $configuration.LunGroup.EnablePipelineBatchCoverage = $true
}
$runId = Get-Date -Format 'yyyyMMddHHmmss'
if (-not $PerformanceOutputPath) {
    $PerformanceOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "dm_integrity_perf_$runId"
}
$moduleRoot = Join-Path (Split-Path -Parent $PSScriptRoot) '..\POSH-Oceanstor'
$moduleRoot = (Resolve-Path -LiteralPath $moduleRoot).Path

$validationModule = New-Module -Name OceanstorLiveGetterValidation -ArgumentList $moduleRoot -ScriptBlock {
    param($root)

    . (Join-Path $root 'Private\class-OceanstorSession.ps1')
    Get-ChildItem -LiteralPath (Join-Path $root 'Private') -Filter 'class-*.ps1' |
        Where-Object Name -ne 'class-OceanstorSession.ps1' |
        ForEach-Object { . $_.FullName }

    foreach ($privateHelper in @(
        'Assert-DMApiSuccess.ps1',
        'Assert-DMValidFilterProperty.ps1',
        'ConvertFrom-DMSensitiveValue.ps1',
        'ConvertTo-DMCapacityBlock.ps1',
        'ConvertTo-DMQuotaByte.ps1',
        'DMPerformanceIndicatorMap.ps1',
        'Get-DMFilterableProperty.ps1',
        'Get-DMApiErrorMessage.ps1',
        'Get-DMparsedElabel.ps1',
        'Get-DMPortGroupCandidate.ps1',
        'Import-DMPerformanceReportCsv.ps1',
        'Import-ReportTemplates.ps1',
        'Invoke-DeviceManager.ps1',
        'Invoke-DMPagedRequest.ps1',
        'New-DMNamedObjectUpdate.ps1',
        'New-DMObjectReport.ps1',
        'Save-DMDeviceManagerFile.ps1',
        'Select-DMResponseData.ps1',
        'Set-DMHostInitiator.ps1',
        'Test-DMNetworkAddress.ps1',
        'Test-WWNAddress.ps1',
        'Write-DMError.ps1'
    )) {
        . (Join-Path $root "Private\$privateHelper")
    }

    Get-ChildItem -LiteralPath (Join-Path $root 'Public') -Filter '*.ps1' |
        ForEach-Object { . $_.FullName }

    function Enable-DMValidationRequestTrace {
        param([System.Collections.Generic.List[object]]$Sink)

        $script:DeviceManagerTraceSink = $Sink
        $script:DeviceManagerTraceAction = {
            param($entry)
            [void]$script:DeviceManagerTraceSink.Add($entry)
        }
    }

    function Set-DMValidationRequestTraceContext {
        param(
            [string]$Name,
            [string]$Category
        )

        $script:DeviceManagerTraceContext = if ($Name) {
            [pscustomobject]@{ Name = $Name; Category = $Category }
        }
        else {
            $null
        }
    }

    Export-ModuleMember -Function '*'
}

Import-Module $validationModule -Force

$checks = [System.Collections.Generic.List[object]]::new()
$GetterIntegrityRunLogPath = $RunLogPath
$GetterIntegrityRunLogEntries = [System.Collections.Generic.List[object]]::new()
$mutationRequests = [System.Collections.Generic.List[object]]::new()
$cleanupActions = [System.Collections.Generic.List[object]]::new()
$sessionDisconnected = $false
$samples = @{}
$owned = @{}
foreach ($kind in @('Lun', 'LunSnapshot', 'HyperCDPSchedule', 'LunGroup', 'ProtectionGroup', 'SnapshotConsistencyGroup', 'QosPolicy', 'Host', 'HostGroup', 'FileSystem', 'FileSystemSnapshot', 'DTree', 'CifsShare', 'NfsShare', 'NfsClient', 'Quota', 'MappingView', 'PortGroup', 'FibreChannelInitiator', 'IscsiInitiator', 'NvmeInitiator', 'ReportTask', 'ReportLog')) {
    $owned[$kind] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
}
$performanceCleanupRegistry = [System.Collections.Generic.List[object]]::new()
$performanceRequests = [System.Collections.Generic.List[object]]::new()
$performanceArtifacts = [ordered]@{}


. (Join-Path $PSScriptRoot 'Private\ValidationHelpers.ps1')
. (Join-Path $PSScriptRoot 'Private\ReadValidation.ps1')
. (Join-Path $PSScriptRoot 'Private\MutationValidation.ps1')
. (Join-Path $PSScriptRoot 'Private\PerformanceValidation.ps1')
. (Join-Path $PSScriptRoot 'Private\Reporting.ps1')

Initialize-ValidationRunLog

try {
    Write-ValidationProgress -Name 'Connect-deviceManager' -Category 'Session'
    $connectionStartedAt = Get-Date
    $connectionArguments = if ($Credential) {
        '-Hostname $Hostname -PassThru -Credential $Credential -SkipCertificateCheck:$SkipCertificateCheck'
    }
    else {
        '-Hostname $Hostname -PassThru -Secure -SkipCertificateCheck:$SkipCertificateCheck'
    }
    $connectionLogEntry = Start-ValidationCommandLogEntry -Name 'Connect-deviceManager' -StartedAt $connectionStartedAt -MainCommand 'Connect-deviceManager' -Arguments $connectionArguments
    try {
        if ($Credential) {
            Write-Host "Connecting to $Hostname using the supplied -Credential. No credentials are read from or written to the configuration file."
            $session = Connect-deviceManager -Hostname $Hostname -PassThru -Credential $Credential -SkipCertificateCheck:$SkipCertificateCheck
        }
        else {
            Write-Host "A credential prompt will open for validation of $Hostname. No credentials are read from or written to the configuration file."
            $session = Connect-deviceManager -Hostname $Hostname -PassThru -Secure -SkipCertificateCheck:$SkipCertificateCheck
        }
    }
    finally {
        Complete-ValidationCommandLogEntry -Entry $connectionLogEntry -EndedAt (Get-Date)
    }
    $connectionDurationMs = [math]::Round(((Get-Date) - $connectionStartedAt).TotalMilliseconds, 2)
    $checks.Add([pscustomobject]@{
        Name         = 'Connect-deviceManager'
        Category     = 'Session'
        Status       = 'Passed'
        DurationMs   = $connectionDurationMs
        Count        = 1
        ExpectedType = 'OceanstorSession'
        ActualTypes  = @($session.GetType().Name)
        Error        = $null
    })
    Write-ValidationProgress -Name 'Connect-deviceManager' -Category 'Session' -Status 'Passed' -DurationMs $connectionDurationMs

    Invoke-ReadValidation
    Invoke-PerformanceValidation
    Invoke-MutationValidation
    Write-ValidationReport
}
finally {
    try {
        Invoke-PerformanceCleanupBackstop
    }
    catch {
        Write-Warning "Performance cleanup backstop failed: $_"
    }
    if ($session -and -not $sessionDisconnected) {
        $disconnectStartedAt = Get-Date
        $disconnectLogEntry = Start-ValidationCommandLogEntry -Name 'Disconnect-deviceManager' -StartedAt $disconnectStartedAt -MainCommand 'Disconnect-deviceManager' -Arguments '-WebSession $session'
        try { Disconnect-deviceManager -WebSession $session } catch { Write-Verbose "Session cleanup failed: $_" } finally { Complete-ValidationCommandLogEntry -Entry $disconnectLogEntry -EndedAt (Get-Date) }
    }
    if (-not $NoProgress) {
        Write-Progress -Id 1 -Activity "Validating OceanStor $Hostname" -Completed
    }
    Remove-Module -Name OceanstorLiveGetterValidation -Force -ErrorAction SilentlyContinue
}
