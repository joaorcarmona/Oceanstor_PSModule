function Enable-DMRequestTrace {
    <#
    .SYNOPSIS
        Turns on debug tracing of every OceanStor REST request and response.

    .DESCRIPTION
        Installs a trace hook into the module's REST layer (Invoke-DeviceManager) so that each
        request/response is captured. Every call records the vendor, host and software version,
        the HTTP method and URI, the request body, the HTTP status code and the OceanStor
        business error.code/description, and the response payload. Secrets (password, token,
        secret, community, iBaseToken) are redacted automatically.

        Captured entries are retained in memory and can be reviewed with Get-DMRequestTrace.
        Unless -Quiet is specified, each request is also printed to the console as a colored
        block as it happens.

        Passwords are never carried in these bodies: the login exchange runs outside this REST
        layer, so trace bodies contain only management payloads.

    .PARAMETER DebugDepth
        Level of detail captured per request:
          1 (default) - structured request/response objects plus HTTP and business codes.
          2           - additionally captures the exact JSON string sent on the wire, the
                        request headers (iBaseToken redacted), and the response re-serialized
                        to JSON. Use for byte-level debugging.

    .PARAMETER LogPath
        Optional path to a file that each trace entry is appended to as one compact JSON object
        per line (JSON Lines). The file and its parent directory are created if missing.

    .PARAMETER Quiet
        Suppresses the live console output. Entries are still collected in memory (and written
        to LogPath if supplied). Use for scripted runs where console noise is unwanted.

    .EXAMPLE
        PS C:\> Enable-DMRequestTrace
        Enables structured (depth 1) tracing with live colored console output.

    .EXAMPLE
        PS C:\> Enable-DMRequestTrace -DebugDepth 2 -LogPath .\dm-debug.jsonl
        Captures exact wire JSON for every request and also appends each entry to a log file.

    .EXAMPLE
        PS C:\> Enable-DMRequestTrace -Quiet
        PS C:\> Get-DMhost | Out-Null
        PS C:\> Get-DMRequestTrace -Last 1 | Format-List
        Collects traces silently, then inspects the most recent one.

    .LINK
        Disable-DMRequestTrace
    .LINK
        Get-DMRequestTrace
    #>
    [CmdletBinding()]
    param(
        [ValidateSet(1, 2)]
        [int]$DebugDepth = 1,

        [string]$LogPath,

        [switch]$Quiet
    )

    # Read via Get-Variable so an unset value does not trip Set-StrictMode when this cmdlet is
    # dot-sourced outside the module (or called before the module initialized its state).
    $entriesVar = Get-Variable -Name DeviceManagerTraceEntries -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $entriesVar -or $null -eq $entriesVar.Value) {
        $script:DeviceManagerTraceEntries = [System.Collections.Generic.List[object]]::new()
    }

    $script:DeviceManagerTraceDepth = $DebugDepth
    $script:DeviceManagerTraceConsole = -not $Quiet

    if ($LogPath) {
        $resolvedLog = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath)
        $logDir = Split-Path -Parent $resolvedLog
        if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $script:DeviceManagerTraceLogPath = $resolvedLog
    }
    else {
        $script:DeviceManagerTraceLogPath = $null
    }

    # The action runs in module scope, so it can reach the private Format-DMTraceConsole
    # helper and the module-scoped sink/config variables set above.
    $script:DeviceManagerTraceAction = {
        param($entry)

        [void]$script:DeviceManagerTraceEntries.Add($entry)

        if ($script:DeviceManagerTraceConsole) {
            try { Format-DMTraceConsole -Entry $entry }
            catch { Write-Verbose "DeviceManager trace console render failed: $($_.Exception.Message)" }
        }

        if ($script:DeviceManagerTraceLogPath) {
            try {
                $line = $entry | ConvertTo-Json -Depth 12 -Compress
                Add-Content -LiteralPath $script:DeviceManagerTraceLogPath -Value $line
            }
            catch { Write-Verbose "DeviceManager trace log write failed: $($_.Exception.Message)" }
        }
    }

    $target = if ($script:DeviceManagerTraceLogPath) { " (logging to $script:DeviceManagerTraceLogPath)" } else { '' }
    Write-Verbose "OceanStor request tracing enabled at depth $DebugDepth$target."
}
