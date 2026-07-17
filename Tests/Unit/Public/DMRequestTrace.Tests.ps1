BeforeAll {
    # Run under StrictMode so the trace cmdlets are exercised the way a user with
    # Set-StrictMode enabled would hit them (reads of unset state / missing members throw).
    Set-StrictMode -Version Latest
    $moduleRoot = "$PSScriptRoot\..\..\..\POSH-Oceanstor"
    # Invoke-DeviceManager.ps1 also defines Write-DMRequestTrace, Copy-DMTraceValue and
    # Format-DMTraceConsole, which the public trace cmdlets rely on. Dot-source everything
    # into this test's script scope so they share the module-scoped ($script:) trace state.
    . "$moduleRoot\Private\Invoke-DeviceManager.ps1"
    . "$moduleRoot\Public\Enable-DMRequestTrace.ps1"
    . "$moduleRoot\Public\Disable-DMRequestTrace.ps1"
    . "$moduleRoot\Public\Get-DMRequestTrace.ps1"
    . "$moduleRoot\Public\Clear-DMRequestTrace.ps1"
}

Describe 'DMRequestTrace cmdlets' {
    BeforeEach {
        $script:session = [pscustomobject]@{
            Hostname             = 'oceanstor.test'
            DeviceId             = 'device-01'
            Version              = '6.1.5'
            Headers              = @{ iBaseToken = 'Test-token' }
            WebSession           = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            SkipCertificateCheck = $false
        }

        Mock Invoke-RestMethod {
            return [pscustomobject]@{
                error = [pscustomobject]@{ code = 0 }
                data  = [pscustomobject]@{ ID = 'lun-01' }
            }
        }
    }

    AfterEach {
        Disable-DMRequestTrace -Clear
        Remove-Variable -Name DeviceManagerTraceDepth -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name DeviceManagerTraceEntries -Scope Script -ErrorAction SilentlyContinue
    }

    It 'Enable + Get captures a request entry silently with -Quiet' {
        Enable-DMRequestTrace -Quiet

        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'

        $entries = Get-DMRequestTrace
        @($entries).Count | Should -Be 1
        $entries[0].Uri | Should -Be 'https://oceanstor.test:8088/deviceManager/rest/device-01/lun'
        $entries[0].Vendor | Should -Be 'Huawei OceanStor'
        $entries[0].Version | Should -Be '6.1.5'
    }

    It 'DebugDepth 2 records exact wire JSON and redacted headers' {
        Enable-DMRequestTrace -DebugDepth 2 -Quiet
        $script:DeviceManagerTraceDepth | Should -Be 2

        $null = Invoke-DeviceManager -WebSession $script:session -Method POST -Resource 'lun' `
            -BodyData @{ NAME = 'wire-lun' }

        $entry = Get-DMRequestTrace -Last 1
        $entry.RawJsonBody | Should -Match 'wire-lun'
        $entry.Headers.iBaseToken | Should -Be '[REDACTED]'
    }

    It 'Disable stops further capture but keeps collected entries' {
        Enable-DMRequestTrace -Quiet
        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'
        Disable-DMRequestTrace

        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'host'

        @(Get-DMRequestTrace).Count | Should -Be 1
    }

    It 'Clear empties the buffer without disabling tracing' {
        Enable-DMRequestTrace -Quiet
        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'

        Clear-DMRequestTrace

        Get-DMRequestTrace | Should -BeNullOrEmpty
        # Still enabled: a subsequent call is captured again.
        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'
        @(Get-DMRequestTrace).Count | Should -Be 1
    }

    It 'LogPath appends one JSON object per request' {
        $logFile = Join-Path $TestDrive 'dm-trace.jsonl'
        Enable-DMRequestTrace -Quiet -LogPath $logFile

        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'
        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'host'

        $lines = Get-Content -LiteralPath $logFile
        @($lines).Count | Should -Be 2
        ($lines[0] | ConvertFrom-Json).Vendor | Should -Be 'Huawei OceanStor'
    }

    It 'Format-DMTraceConsole renders the vendor header, URI and status' {
        Enable-DMRequestTrace -Quiet
        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'
        $entry = Get-DMRequestTrace -Last 1

        # Write-Host emits to the information stream (6) in PowerShell 7.
        $rendered = (Format-DMTraceConsole -Entry $entry 6>&1 | Out-String)
        $rendered | Should -Match 'Huawei OceanStor'
        $rendered | Should -Match 'device-01/lun'
        $rendered | Should -Match 'HTTP 200'
    }
}
