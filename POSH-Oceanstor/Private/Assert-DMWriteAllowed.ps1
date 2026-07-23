function Assert-DMWriteAllowed {
    <#
    .SYNOPSIS
        Blocks array-mutating REST calls at runtime while the module is in ReadOnly access mode.

    .DESCRIPTION
        Runtime half of the transversal ReadOnly guardrail. The import-time export filter in
        POSH-Oceanstor.psm1 hides mutation commands, but any command already resolved into a
        session stays callable until the next re-import; this helper closes that gap by enforcing
        the policy at the single REST choke point (Invoke-DeviceManager) every session-based array
        call flows through. Because it consults the LIVE config, Set-DMAccessMode -Mode ReadOnly
        starts blocking writes immediately -- no Import-Module -Force needed to arm the brake.

        The decision keys off the ORIGINATING public cmdlet's verb, not the HTTP method, matching
        the export-filter policy exactly (Get-DMAccessModePolicy):
          - Verb in ReadOnlyVerbs (Get/Connect/Disconnect/Export) or command in ExemptCommands
            -> always allowed. The live config is never even read, so read-heavy paths pay nothing.
            This is why a Get-* cmdlet that queries via POST is allowed and Disconnect's DELETE works.
          - Otherwise the call is a mutation: resolve the live mode; throw in ReadOnly, allow in
            ReadWrite.
          - When the originating command is unknown (a direct Invoke-DeviceManager call with no
            public frame on the stack), the HTTP method is the fallback: GET is a read; any write
            method is checked against the live mode.

    .PARAMETER Method
        The HTTP method of the REST call (GET/POST/PUT/DELETE). Fallback signal when the
        originating command cannot be determined.

    .PARAMETER Command
        The originating public cmdlet the user invoked (e.g. 'New-DMLun'). Empty when unknown.

    .PARAMETER ConfigPath
        Override the config location used to resolve the live mode. Defaults to the standard
        per-user config (via Get-DMAccessModeState). Intended for tests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$Method,

        [AllowEmptyString()]
        [string]$Command = '',

        [string]$ConfigPath
    )

    $policy = Get-DMAccessModePolicy

    if (-not [string]::IsNullOrWhiteSpace($Command)) {
        $verb = ($Command -split '-', 2)[0]
        $isRead = ($verb -in $policy.ReadOnlyVerbs) -or ($Command -in $policy.ExemptCommands)
    }
    else {
        # Unknown caller: only GET is a guaranteed read.
        $isRead = ($Method -eq 'GET')
    }

    if ($isRead) {
        return
    }

    # Mutation path only: consult the LIVE mode so Set-DMAccessMode is effective without a re-import.
    $mode = if ($PSBoundParameters.ContainsKey('ConfigPath')) {
        Get-DMAccessModeState -ConfigPath $ConfigPath
    }
    else {
        Get-DMAccessModeState
    }

    if ($mode -eq 'ReadOnly') {
        $target = if ([string]::IsNullOrWhiteSpace($Command)) { "this $Method request" } else { "'$Command'" }
        throw "POSH-Oceanstor is in ReadOnly access mode; $target is blocked. Run 'Set-DMAccessMode -Mode ReadWrite' (then re-import to restore the hidden commands) to allow write operations."
    }
}
