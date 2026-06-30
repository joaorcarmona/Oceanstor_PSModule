[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Hostname,

    [string]$ReportPath = (Join-Path $PSScriptRoot 'getter-integrity-last-result.json'),

    [string]$MutationLogPath = (Join-Path $PSScriptRoot 'mutation-trace-last-result.json'),

    [string]$ConfigurationPath = (Join-Path $PSScriptRoot 'IntegrityValidationConfig.psd1'),

    [switch]$RunMutatingTests,

    [switch]$NoProgress,

    [switch]$ShowTestExecution
)

$ErrorActionPreference = 'Stop'
$runStartedAt = Get-Date
$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
$runId = Get-Date -Format 'yyyyMMddHHmmss'
$moduleRoot = Join-Path (Split-Path -Parent $PSScriptRoot) '..\POSH-Oceanstor'
$moduleRoot = (Resolve-Path -LiteralPath $moduleRoot).Path

$validationModule = New-Module -Name OceanstorLiveGetterValidation -ArgumentList $moduleRoot -ScriptBlock {
    param($root)

    . (Join-Path $root 'Private\class-OceanstorSession.ps1')
    Get-ChildItem -LiteralPath (Join-Path $root 'Private') -Filter 'class-*.ps1' |
        Where-Object Name -ne 'class-OceanstorSession.ps1' |
        ForEach-Object { . $_.FullName }

    foreach ($privateHelper in @(
        'ConvertTo-DMCapacityBlock.ps1',
        'Get-DMparsedElabel.ps1',
        'Get-DMPortGroupCandidate.ps1',
        'Invoke-DeviceManager.ps1',
        'Invoke-DMPagedRequest.ps1',
        'New-DMNamedObjectUpdate.ps1',
        'Set-DMHostInitiator.ps1',
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
$mutationRequests = [System.Collections.Generic.List[object]]::new()
$cleanupActions = [System.Collections.Generic.List[object]]::new()
$sessionDisconnected = $false
$samples = @{}
$owned = @{}
foreach ($kind in @('Lun', 'LunSnapshot', 'LunGroup', 'ProtectionGroup', 'SnapshotConsistencyGroup', 'Host', 'HostGroup', 'FileSystem', 'FileSystemSnapshot', 'DTree', 'CifsShare', 'NfsShare', 'NfsClient', 'MappingView', 'PortGroup', 'FibreChannelInitiator', 'IscsiInitiator', 'NvmeInitiator')) {
    $owned[$kind] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
}


. (Join-Path $PSScriptRoot 'Private\ValidationHelpers.ps1')
. (Join-Path $PSScriptRoot 'Private\ReadValidation.ps1')
. (Join-Path $PSScriptRoot 'Private\MutationValidation.ps1')
. (Join-Path $PSScriptRoot 'Private\Reporting.ps1')

try {
    Write-Host "A credential prompt will open for validation of $Hostname. No credentials are read from or written to the configuration file."
    Write-ValidationProgress -Name 'Connect-deviceManager' -Category 'Session'
    $connectionStartedAt = Get-Date
    $session = Connect-deviceManager -Hostname $Hostname -PassThru -Secure
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
    Invoke-MutationValidation
    Write-ValidationReport
}
finally {
    if ($session -and -not $sessionDisconnected) {
        try { Disconnect-deviceManager -WebSession $session } catch { Write-Verbose "Session cleanup failed: $_" }
    }
    if (-not $NoProgress) {
        Write-Progress -Id 1 -Activity "Validating OceanStor $Hostname" -Completed
    }
    Remove-Module -Name OceanstorLiveGetterValidation -Force -ErrorAction SilentlyContinue
}
