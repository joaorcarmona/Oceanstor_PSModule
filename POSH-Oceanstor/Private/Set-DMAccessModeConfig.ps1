function Set-DMAccessModeConfig {
    <#
    .SYNOPSIS
        Persists the access-mode ('Mode') setting to the per-user config JSON.

    .DESCRIPTION
        Shared writer behind Set-DMAccessMode. Reads the existing config file tolerantly (a broken
        file is replaced, never a hard failure), preserves every existing feature-override key
        verbatim, and manages only the reserved 'Mode' key:

          - Mode = 'ReadOnly'  -> writes "Mode":"ReadOnly".
          - Mode = 'ReadWrite' -> removes the key entirely (ReadWrite is the built-in default, so it
                                  is never stored -- mirrors the feature writer's "store only
                                  non-default overrides" rule).

        Creates the config directory on first write. Returns the effective mode string written.

    .PARAMETER Mode
        Desired access mode: 'ReadOnly' or 'ReadWrite'.

    .PARAMETER ConfigPath
        Override the user-config location. Defaults to Get-DMFeatureConfigPath.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType('System.String')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ReadOnly', 'ReadWrite')]
        [string]$Mode,

        [string]$ConfigPath = (Get-DMFeatureConfigPath)
    )

    # Seed from whatever config already exists; a corrupt file is discarded, not fatal. Every key
    # other than the reserved 'Mode' (i.e. the feature overrides) is preserved unchanged.
    $config = @{}
    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            $raw = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
                foreach ($property in $parsed.PSObject.Properties) {
                    if ($property.Name -eq 'Mode') { continue }
                    $config[$property.Name] = $property.Value
                }
            }
        }
        catch {
            Write-Warning "POSH-Oceanstor feature config at '$ConfigPath' was unreadable ($($_.Exception.Message)); rewriting, preserving no feature overrides."
            $config = @{}
        }
    }

    # ReadWrite is the default and is never stored; ReadOnly is the only value written.
    if ($Mode -eq 'ReadOnly') {
        $config['Mode'] = 'ReadOnly'
    }

    $configDir = Split-Path -Path $ConfigPath -Parent
    if ($configDir -and -not (Test-Path -LiteralPath $configDir)) {
        $null = New-Item -Path $configDir -ItemType Directory -Force
    }

    ($config | ConvertTo-Json) | Set-Content -LiteralPath $ConfigPath -Encoding utf8
    return $Mode
}
