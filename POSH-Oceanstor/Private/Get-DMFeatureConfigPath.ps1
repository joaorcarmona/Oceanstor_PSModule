function Get-DMFeatureConfigPath {
    <#
    .SYNOPSIS
        Returns the path to the per-user feature-override JSON config.

    .DESCRIPTION
        Feature enable/disable overrides are stored in a per-user JSON file at
        %APPDATA%\POSH-Oceanstor\ModuleConfig.json. The file only holds explicit overrides;
        a missing file or key means the built-in DMFeatureMap.psd1 default applies.

        Set $env:POSH_OCEANSTOR_CONFIG_PATH to redirect the location -- used by labs, CI, and
        the Pester suites so tests never touch the real user profile.

        This resolves the path only; it never creates the file or directory.
    #>
    [CmdletBinding()]
    [OutputType('System.String')]
    param()

    if ($env:POSH_OCEANSTOR_CONFIG_PATH) {
        return $env:POSH_OCEANSTOR_CONFIG_PATH
    }

    $appData = [System.Environment]::GetFolderPath('ApplicationData')
    return Join-Path -Path $appData -ChildPath 'POSH-Oceanstor\ModuleConfig.json'
}
